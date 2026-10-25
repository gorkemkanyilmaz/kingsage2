import io
import os
import sys
import urllib.request
import zipfile

class RangeHTTPFile(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=15) as r:
            self._size = int(r.headers.get("Content-Length"))
        self._pos = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self._pos = offset
        elif whence == io.SEEK_CUR:
            self._pos += offset
        elif whence == io.SEEK_END:
            self._pos = self._size + offset
        self._pos = max(0, min(self._pos, self._size))
        return self._pos

    def tell(self):
        return self._pos

    def readinto(self, b):
        if self._pos >= self._size:
            return 0
        l = len(b)
        req = urllib.request.Request(self.url)
        end = min(self._size - 1, self._pos + l - 1)
        req.headers["Range"] = f"bytes={self._pos}-{end}"
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        b[: len(data)] = data
        self._pos += len(data)
        return len(data)

target_dir = os.path.expandvars(r"%APPDATA%\Godot\export_templates\4.7.2.stable")
os.makedirs(target_dir, exist_ok=True)
print(f"Hedef Şablon Klasörü: {target_dir}")

url = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
print("Uzak zip arşivi açılıyor...")
stream = io.BufferedReader(RangeHTTPFile(url), buffer_size=128 * 1024)
z = zipfile.ZipFile(stream)

web_members = [
    n for n in z.namelist()
    if n.startswith("templates/") and ("web" in n or "version" in n)
]

print(f"İndirilecek dosya sayısı: {len(web_members)}")
for name in web_members:
    dest_filename = os.path.basename(name)
    dest_path = os.path.join(target_dir, dest_filename)
    info = z.getinfo(name)
    size_kb = info.file_size // 1024
    print(f"-> İndiriliyor: {dest_filename} ({size_kb} KB)...", end=" ", flush=True)

    with z.open(name) as src, open(dest_path, "wb") as dst:
        while True:
            chunk = src.read(256 * 1024)
            if not chunk:
                break
            dst.write(chunk)
    print("TAMAMLANDI!")

print("\n🎉 Tüm Web Dışa Aktarma Şablonları Başarıyla Kuruldu!")
