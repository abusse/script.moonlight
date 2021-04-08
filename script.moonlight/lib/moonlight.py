import ctypes
import os
from uuid import uuid4

GS_OK = 0
GS_FAILED = -1
GS_OUT_OF_MEMORY = -2
GS_INVALID = -3
GS_WRONG_STATE = -4
GS_IO_ERROR = -5
GS_NOT_SUPPORTED_4K = -6

class DISPLAY_MODE(ctypes.Structure):
    pass

DISPLAY_MODE._fields_ = [("height", ctypes.c_uint),
                         ("width", ctypes.c_uint),
                         ("refresh", ctypes.c_uint),
                         ("__next__", ctypes.POINTER(DISPLAY_MODE))]

class SERVER_INFORMATION(ctypes.Structure):
    _fields_ = [("address", ctypes.c_char_p),
                ("serverInfoAppVersion", ctypes.c_char_p),
                ("serverInfoGfeVersion", ctypes.c_char_p)]

class SERVER_DATA(ctypes.Structure):
    _fields_ = [("address", ctypes.c_char_p),
                ("gpuType", ctypes.c_char_p),
                ("paired", ctypes.c_bool),
                ("supports4K", ctypes.c_bool),
                ("unsupported", ctypes.c_bool),
                ("currentGame", ctypes.c_int),
                ("serverMajorVersion", ctypes.c_int),
                ("gsVersion", ctypes.c_char_p),
                ("modes", ctypes.POINTER(DISPLAY_MODE)),
                ("serverInfo", SERVER_INFORMATION)]

class APP_LIST(ctypes.Structure):
    pass

APP_LIST._fields_ = [("name", ctypes.c_char_p),
                     ("id", ctypes.c_int),
                     ("__next__", ctypes.POINTER(APP_LIST))]

class _HTTP_DATA(ctypes.Structure):
    _fields_ = [("memory", ctypes.POINTER(ctypes.c_ubyte)),
                ("size", ctypes.c_size_t)]

def findlib(name):
    libdirs = os.environ['LD_LIBRARY_PATH'].split(':')
    for dir in libdirs:
        for file in os.listdir(dir):
            if file.find(name) != -1:
                return os.path.join(dir, file)

class LibGameStream:
    def __init__(self, libpath = ""):
        self.commonlib = ctypes.cdll.LoadLibrary("/usr/lib64/libmoonlight-common.so")
        self.gslib = ctypes.cdll.LoadLibrary("/usr/lib64/libgamestream.so")
        self.connected = False
        self.address = ""
        self.key_dir = ""

    def discover_server(self):
        addr = ctypes.create_string_buffer('\000' * 40)
        self.gslib.gs_discover_server(addr)
        return addr.value

    def connect_server(self, address, key_dir = ""):
        self.server = ctypes.pointer(SERVER_DATA(address.encode('ascii'), False, False, 0, 0))
        self.address = address
        # The value will be put in the serverInfo data structure, so we have to make sure it doesn't get freed
        self.address_pt = ctypes.c_char_p(address.encode('ascii'))

        if key_dir == "":
            if "XDG_CONFIG_DIR" in os.environ:
                key_dir = os.path.join(os.environ["XDG_CONFIG_DIR"], "moonlight")
            else:
                key_dir = os.path.join(os.environ["HOME"], ".cache", "moonlight")

        self.key_dir = key_dir

        ret = self.gslib.gs_init(self.server, self.address_pt, ctypes.c_char_p(key_dir.encode('ascii')), 0, 0)

        if ret == GS_OK:
            self.connected = True
            return True
        return False

    def isPaired(self):
        if not self.connected:
            return False

        return self.server[0].paired

    def applist(self):
        if not self.connected:
            return None

        lst = []
        applst_ptr = ctypes.POINTER(APP_LIST)
        applst = applst_ptr()

        ret = self.gslib.gs_applist(self.server, ctypes.byref(applst))
        if ret != GS_OK:
            return None

        while applst:
            lst.append((applst[0].id, applst[0].name))
            applst = applst[0].__next__

        return lst

    def poster(self, appId, toFolder):
        unique_id = ""
        with open(os.path.join(self.key_dir, "uniqueid.dat"), "r") as f:
            unique_id = f.read()

        uid = uuid4()
        url = "https://%s:47984/appasset?uniqueid=%s&uuid=%s&appid=%d&AssetType=2&AssetIdx=0" % (self.address, unique_id, str(uid), appId)

        self.gslib.http_create_data.restype = ctypes.POINTER(_HTTP_DATA)
        data = self.gslib.http_create_data();
        self.gslib.http_request(ctypes.c_char_p(url), data)

        barray = bytearray(data[0].memory[0:data[0].size])

        with open(os.path.join(toFolder, str(appId) + ".png"), "wb") as f:
            f.write(barray)

        self.gslib.http_free_data(data);

    def pair(self, pin):
        if not self.connected:
            return None

        ret = self.gslib.gs_pair(self.server, ctypes.c_char_p(pin))
        return ret == GS_OK
