#include <jni.h>
#include <atomic>
#include <chrono>
#include <string>
#include <thread>
extern "C" {
#include <libavformat/avformat.h>
#include <libavutil/log.h>
}

using Clock = std::chrono::steady_clock;

struct Recorder {
    std::atomic<bool> cancel{false};
    std::atomic<int> state{0};
    Clock::time_point deadline;
    std::thread worker;
};

static int interrupted(void* opaque) {
    auto* recorder = static_cast<Recorder*>(opaque);
    return recorder->cancel || Clock::now() > recorder->deadline;
}

static void record(Recorder* recorder, const std::string& url, const std::string& path) {
    av_log_set_level(AV_LOG_QUIET);
    AVFormatContext* input = avformat_alloc_context();
    AVFormatContext* output = nullptr;
    AVPacket* packet = av_packet_alloc();
    bool header = false;
    int video = -1;
    int result = -1;
    int64_t firstDts = AV_NOPTS_VALUE;
    bool started = false;
    AVDictionary* options = nullptr;
    if (!input || !packet) goto finish;
    input->interrupt_callback = {interrupted, recorder};
    recorder->deadline = Clock::now() + std::chrono::seconds(12);
    av_dict_set(&options, "rtsp_transport", "tcp", 0);
    av_dict_set(&options, "timeout", "10000000", 0);
    result = avformat_open_input(&input, url.c_str(), nullptr, &options);
    av_dict_free(&options);
    if (result < 0) goto finish;
    result = avformat_find_stream_info(input, nullptr);
    if (result < 0) goto finish;
    video = av_find_best_stream(input, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (video < 0) goto finish;
    if (input->streams[video]->codecpar->codec_id != AV_CODEC_ID_H264 &&
        input->streams[video]->codecpar->codec_id != AV_CODEC_ID_HEVC) goto finish;
    result = avformat_alloc_output_context2(&output, nullptr, "matroska", path.c_str());
    if (result < 0 || !output) goto finish;
    output->interrupt_callback = {interrupted, recorder};
    {
        AVStream* stream = avformat_new_stream(output, nullptr);
        if (!stream) goto finish;
        result = avcodec_parameters_copy(stream->codecpar, input->streams[video]->codecpar);
        if (result < 0) goto finish;
        stream->codecpar->codec_tag = 0;
        stream->time_base = input->streams[video]->time_base;
    }
    result = avio_open(&output->pb, path.c_str(), AVIO_FLAG_WRITE);
    if (result < 0) goto finish;
    result = avformat_write_header(output, nullptr);
    if (result < 0) goto finish;
    header = true;
    while (!recorder->cancel) {
        recorder->deadline = Clock::now() + std::chrono::seconds(12);
        result = av_read_frame(input, packet);
        if (result < 0) break;
        if (packet->stream_index != video || (!started && !(packet->flags & AV_PKT_FLAG_KEY))) {
            av_packet_unref(packet);
            continue;
        }
        started = true;
        if (packet->dts == AV_NOPTS_VALUE) packet->dts = packet->pts;
        if (packet->pts == AV_NOPTS_VALUE) packet->pts = packet->dts;
        if (packet->dts == AV_NOPTS_VALUE) { av_packet_unref(packet); continue; }
        if (firstDts == AV_NOPTS_VALUE) firstDts = packet->dts;
        packet->dts -= firstDts;
        packet->pts -= firstDts;
        av_packet_rescale_ts(packet, input->streams[video]->time_base, output->streams[0]->time_base);
        packet->stream_index = 0;
        packet->pos = -1;
        result = av_interleaved_write_frame(output, packet);
        av_packet_unref(packet);
        if (result < 0) break;
        avio_flush(output->pb);
        if (output->pb->error < 0) { result = output->pb->error; break; }
        recorder->state = 1;
    }
finish:
    av_dict_free(&options);
    if (packet) av_packet_free(&packet);
    if (header) av_write_trailer(output);
    if (output && output->pb) avio_closep(&output->pb);
    if (output) avformat_free_context(output);
    if (input) avformat_close_input(&input);
    recorder->state = recorder->cancel ? 2 : -1;
}

extern "C" JNIEXPORT jlong JNICALL
Java_in_dagar_home_1cameras_NativeRecorder_start(JNIEnv* env, jobject, jstring uri, jstring file) {
    const char* rawUri = env->GetStringUTFChars(uri, nullptr);
    const char* rawFile = env->GetStringUTFChars(file, nullptr);
    std::string url(rawUri), path(rawFile);
    env->ReleaseStringUTFChars(uri, rawUri);
    env->ReleaseStringUTFChars(file, rawFile);
    auto* recorder = new Recorder();
    recorder->worker = std::thread(record, recorder, url, path);
    return reinterpret_cast<jlong>(recorder);
}

extern "C" JNIEXPORT jint JNICALL
Java_in_dagar_home_1cameras_NativeRecorder_status(JNIEnv*, jobject, jlong handle) {
    return reinterpret_cast<Recorder*>(handle)->state.load();
}

extern "C" JNIEXPORT void JNICALL
Java_in_dagar_home_1cameras_NativeRecorder_cancel(JNIEnv*, jobject, jlong handle) {
    reinterpret_cast<Recorder*>(handle)->cancel = true;
}

extern "C" JNIEXPORT void JNICALL
Java_in_dagar_home_1cameras_NativeRecorder_stop(JNIEnv*, jobject, jlong handle) {
    auto* recorder = reinterpret_cast<Recorder*>(handle);
    recorder->cancel = true;
    recorder->worker.join();
    delete recorder;
}
