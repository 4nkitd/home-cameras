import base64
import hashlib
import hmac
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from xml.etree import ElementTree as ET

HOST = os.environ.get("FIXTURE_CLIENT_HOST", "10.0.2.2")
PASSWORD = "test-camera-only"


def local_name(tag):
    return tag.split("}")[-1]


def element_text(root, name):
    return next((e.text or "" for e in root.iter() if local_name(e.tag) == name), "")


def authenticated(root):
    try:
        nonce = base64.b64decode(element_text(root, "Nonce"))
        created = element_text(root, "Created")
        expected = base64.b64encode(
            hashlib.sha1(nonce + created.encode() + PASSWORD.encode()).digest()
        ).decode()
        return element_text(root, "Username") == "viewer" and hmac.compare_digest(
            element_text(root, "Password"), expected
        )
    except Exception:
        return False


def profile(token, name, width, height):
    return f'''<trt:Profiles token="{token}" fixed="true"><tt:Name>{name}</tt:Name>
<tt:VideoSourceConfiguration token="source1"><tt:Name>Source</tt:Name><tt:UseCount>2</tt:UseCount><tt:SourceToken>sensor1</tt:SourceToken><tt:Bounds x="0" y="0" width="960" height="540"/></tt:VideoSourceConfiguration>
<tt:VideoEncoderConfiguration token="encoder-{token}"><tt:Name>{name}</tt:Name><tt:UseCount>1</tt:UseCount><tt:Encoding>H264</tt:Encoding><tt:Resolution><tt:Width>{width}</tt:Width><tt:Height>{height}</tt:Height></tt:Resolution><tt:Quality>4</tt:Quality><tt:SessionTimeout>PT60S</tt:SessionTimeout></tt:VideoEncoderConfiguration></trt:Profiles>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        if length > 65536:
            self.send_error(413)
            return
        try:
            root = ET.fromstring(self.rfile.read(length))
            body = next(e for e in root.iter() if local_name(e.tag) == "Body")
            operation = local_name(list(body)[0].tag)
        except Exception:
            self.send_error(400)
            return
        if operation != "GetSystemDateAndTime" and not authenticated(root):
            self.send_error(401)
            return
        if operation == "GetSystemDateAndTime":
            now = datetime.now(timezone.utc)
            response = f"""<tds:GetSystemDateAndTimeResponse><tds:SystemDateAndTime><tt:DateTimeType>Manual</tt:DateTimeType><tt:DaylightSavings>false</tt:DaylightSavings><tt:TimeZone><tt:TZ>UTC</tt:TZ></tt:TimeZone><tt:UTCDateTime><tt:Time><tt:Hour>{now.hour}</tt:Hour><tt:Minute>{now.minute}</tt:Minute><tt:Second>{now.second}</tt:Second></tt:Time><tt:Date><tt:Year>{now.year}</tt:Year><tt:Month>{now.month}</tt:Month><tt:Day>{now.day}</tt:Day></tt:Date></tt:UTCDateTime></tds:SystemDateAndTime></tds:GetSystemDateAndTimeResponse>"""
        elif operation == "GetServices":
            response = f"""<tds:GetServicesResponse><tds:Service><tds:Namespace>http://www.onvif.org/ver10/media/wsdl</tds:Namespace><tds:XAddr>http://{HOST}:8899/onvif/media_service</tds:XAddr><tds:Version><tt:Major>2</tt:Major><tt:Minor>0</tt:Minor></tds:Version></tds:Service></tds:GetServicesResponse>"""
        elif operation == "GetProfiles":
            response = (
                "<trt:GetProfilesResponse>"
                + profile("main", "Main stream", 960, 540)
                + profile("sub", "Substream", 320, 180)
                + "</trt:GetProfilesResponse>"
            )
        elif operation == "GetStreamUri":
            token = element_text(root, "ProfileToken")
            path = "sub" if token == "sub" else "front"
            response = f"""<trt:GetStreamUriResponse><trt:MediaUri><tt:Uri>rtsp://{HOST}:8554/{path}</tt:Uri><tt:InvalidAfterConnect>false</tt:InvalidAfterConnect><tt:InvalidAfterReboot>false</tt:InvalidAfterReboot><tt:Timeout>PT0S</tt:Timeout></trt:MediaUri></trt:GetStreamUriResponse>"""
        else:
            self.send_error(400)
            return
        envelope = f"""<?xml version="1.0"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:trt="http://www.onvif.org/ver10/media/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema"><s:Body>{response}</s:Body></s:Envelope>""".encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/soap+xml; charset=utf-8")
        self.send_header("Content-Length", str(len(envelope)))
        self.end_headers()
        self.wfile.write(envelope)


ThreadingHTTPServer(("127.0.0.1", 8899), Handler).serve_forever()
