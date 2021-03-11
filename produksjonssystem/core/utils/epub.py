# -*- coding: utf-8 -*-

import os
import shutil
import pathlib
import re
import stat
import tempfile
import zipfile

from lxml import etree as ElementTree

from core.utils.xslt import Xslt
from core.utils.filesystem import Filesystem


class Epub():
    """Methods for working with EPUB files/filesets"""

    report = None
    _metadata = None
    book_path = None
    book_path_file = None
    book_path_dir = None
    _temp_obj_file = None
    _temp_obj_dir = None

    uid = "core-utils-epub"

    def __init__(self, report, book_path):
        if not os.path.exists(book_path):
            report.error("Epub {} finnes ikke lenger.".format(book_path))
        self.report = report
        self.book_path = book_path

    def asFile(self, rebuild=False):
        """Return the epub as a zip file and with file extension "epub"."""

        # optionally discard existing build to force a rebuild
        if rebuild:
            self.book_path_file = None
            self._temp_obj_file = None

        # return existing build if present
        if self.book_path_file:
            return self.book_path_file

        # If the source is a file, and there's no unzipped version of the EPUB,
        # then simply use the source file.
        if os.path.isfile(self.book_path) and not self.book_path_dir:
            self.book_path_file = self.book_path
            return self.book_path_file

        # Determine which directory to use as input for zipping
        dirpath = None
        if self.book_path_dir:
            # prefer the already unzipped version, as this may contain changes
            dirpath = pathlib.Path(self.book_path_dir)
        else:
            # use the source directory if there's no unzipped version present
            dirpath = pathlib.Path(self.book_path)

        # create the temporary directory for the file
        if not self._temp_obj_file:
            self._temp_obj_file = tempfile.TemporaryDirectory()

        # zip directory according to the EPUB OCF specification
        file = os.path.join(self._temp_obj_file.name, self.identifier() + ".epub")
        with zipfile.ZipFile(file, 'w') as archive:
            mimetype = dirpath / 'mimetype'
            if not os.path.isfile(str(mimetype)):
                with open(str(mimetype), "w") as f:
                    self.report.debug("creating mimetype file")
                    f.write("application/epub+zip")
            self.report.debug("zipping: mimetype")
            archive.write(str(mimetype), 'mimetype', compress_type=zipfile.ZIP_STORED)
            for f in dirpath.rglob('*'):
                relative = str(f.relative_to(dirpath))
                if relative == "mimetype":
                    continue
                self.report.debug("zipping: " + relative)
                archive.write(str(f), relative, compress_type=zipfile.ZIP_DEFLATED)

        return file

    def asDir(self):
        # return existing directory if present
        if self.book_path_dir:
            return self.book_path_dir

        # if the source path is a directory; use the source directory
        if os.path.isdir(self.book_path):
            self.book_path_dir = self.book_path
            return self.book_path_dir

        # otherwise unzip the source file to a temporary directory,
        # and use that one instead
        else:
            self._temp_obj_dir = tempfile.TemporaryDirectory()
            self.book_path_dir = self._temp_obj_dir.name
            Filesystem.unzip(self.report, self.book_path, self.book_path_dir)
            return self.book_path_dir

    def isepub(self, report_errors=True):
        # EPUBen må inneholde en "EPUB/package.opf"-fil (en ekstra sjekk for å være sikker på at dette er et EPUB-filsett)
        if os.path.isdir(self.book_path) and not os.path.isfile(os.path.join(self.book_path, "EPUB/package.opf")):
            if report_errors:
                self.report.error(
                    os.path.basename(self.book_path) + ": EPUB/package.opf eksisterer ikke. Kan ikke validere EPUB.")
            return False

        elif os.path.isfile(self.book_path):
            try:
                with zipfile.ZipFile(self.book_path, 'r') as archive:
                    if "mimetype" not in [item.filename for item in archive.filelist]:
                        if report_errors:
                            self.report.warn("No 'mimetype' file in ZIP; this is not an EPUB: " + self.book_path)
                        return False

                    mimetype = archive.read("mimetype").decode("utf-8")
                    if not mimetype.startswith("application/epub+zip"):
                        if report_errors:
                            self.report.warn(
                                "The 'mimetype' file does not start with the text 'application/epub+zip'; this is not an EPUB: " + self.book_path)
                        return False

                    if "META-INF/container.xml" not in [item.filename for item in archive.filelist]:
                        if report_errors:
                            self.report.warn("No 'META-INF/container.xml' file in ZIP; this is not an EPUB: " + self.book_path)
                        return False

            except zipfile.BadZipfile:
                if report_errors:
                    self.report.warn("The book is a file, but not a ZIP file. This is not an EPUB: " + self.book_path)
                return False

        return True

    def opf_path(self):
        container = None

        if os.path.isdir(self.book_path):
            container = ElementTree.parse(os.path.join(self.book_path, "META-INF/container.xml")).getroot()

        elif os.path.isfile(self.book_path):
            with zipfile.ZipFile(self.book_path, 'r') as archive:
                container = archive.read("META-INF/container.xml")
                container = ElementTree.XML(container)

        else:
            return None

        rootfiles = container.findall('{urn:oasis:names:tc:opendocument:xmlns:container}rootfiles')[0]
        rootfile = rootfiles.findall('{urn:oasis:names:tc:opendocument:xmlns:container}rootfile')[0]
        opf = rootfile.attrib["full-path"]
        return opf

    def get_opf_package_element(self):
        opf_path = self.opf_path()

        if os.path.isdir(self.book_path):
            return ElementTree.parse(os.path.join(self.book_path, opf_path)).getroot()

        elif os.path.isfile(self.book_path):
            with zipfile.ZipFile(self.book_path, 'r') as archive:
                opf = archive.read(opf_path)
                return ElementTree.XML(opf)

        else:
            return None

    def nav_path(self):
        opf = self.get_opf_package_element()

        if opf is None:
            return None

        manifest = opf.findall('{http://www.idpf.org/2007/opf}manifest')[0]
        items = manifest.findall("*")
        for item in items:
            if "properties" in item.attrib and "nav" in re.split(r'\s+', item.attrib["properties"]):
                return os.path.join(os.path.dirname(self.opf_path()), item.attrib["href"])

        return None

    def identifier(self, default=None):
        return self.meta("dc:identifier")

    def spine(self):
        opf = self.get_opf_package_element()

        if opf is None:
            return None

        ns = {"opf": "http://www.idpf.org/2007/opf"}
        itemrefs = opf.xpath("//opf:spine/opf:itemref", namespaces=ns)
        spine = []
        for itemref in itemrefs:
            item = opf.xpath("//opf:manifest/opf:item[@id = '{}']".format(itemref.attrib["idref"]), namespaces=ns)
            data = {}
            for a in itemref.attrib:
                data[a] = itemref.attrib[a]
            for a in item[0].attrib:
                data[a] = item[0].attrib[a]
            del data["idref"]
            spine.append(data)

        return spine

    def metadata(self):
        """Read OPF metadata"""
        if not self._metadata:
            opf = self.get_opf_package_element()
            self._metadata = {}

            if opf is None:
                return self._metadata

            opf_metadata = opf.findall('{http://www.idpf.org/2007/opf}metadata')[0]
            for m in opf_metadata.findall("*"):
                if "refines" in m.attrib:
                    continue
                n = m.attrib["property"] if "property" in m.attrib else m.attrib["name"] if "name" in m.attrib else m.tag
                n = n.replace("{http://purl.org/dc/elements/1.1/}", "dc:")
                value = m.attrib["content"] if "content" in m.attrib else m.text
                self._metadata[n] = value

        return self._metadata

    def meta(self, name, default=None):
        self.metadata()  # make sure self._metadata is defined
        return self._metadata[name] if name in self._metadata else default

    def refresh_metadata(self):
        self._metadata = None
        self.metadata()

    # iterates over the package document and all the content documents and updates their "prefix"/"epub:prefix" attributes
    def update_prefixes(self):
        temp_xml_file_obj = tempfile.NamedTemporaryFile()
        temp_xml_file = temp_xml_file_obj.name

        opf_path = os.path.join(self.book_path, self.opf_path())

        xslt = Xslt(report=self.report,
                    stylesheet=os.path.join(Xslt.xslt_dir, Epub.uid, "update-epub-prefixes.xsl"),
                    source=opf_path,
                    target=temp_xml_file)
        if not xslt.success:
            return False
        shutil.copy(temp_xml_file, opf_path)

        opf_element = self.get_opf_package_element()
        html_paths = opf_element.xpath("/*/*[local-name()='manifest']/*[@media-type='application/xhtml+xml']/@href")
        for html_relpath in html_paths:
            html_path = os.path.normpath(os.path.join(os.path.dirname(opf_path), html_relpath))

            xslt = Xslt(report=self.report,
                        stylesheet=os.path.join(Xslt.xslt_dir, Epub.uid, "update-epub-prefixes.xsl"),
                        source=html_path,
                        target=temp_xml_file)
            if not xslt.success:
                return False
            shutil.copy(temp_xml_file, html_path)

        return True

    # Iterates over the content documents in the OPF manifest and updates their property attributes.
    # Also updates the spine linear property, and adds a reference to the cover image in the metadata.
    def update_opf_properties(self):
        opf_path = os.path.join(self.book_path, self.opf_path())

        opf_element = self.get_opf_package_element()
        metadata = opf_element.xpath("/*/*[local-name()='metadata']")[0]
        manifest = opf_element.xpath("/*/*[local-name()='manifest']")[0]
        spine = opf_element.xpath("/*/*[local-name()='spine']")[0]

        cover_id = None
        types = {}

        for item in manifest:
            properties = set()

            if item.attrib.get("href", "").split("/")[-1] in ["cover.jpg", "cover.jpeg", "cover.png"]:
                properties.add("cover-image")
                cover_id = item.attrib.get("id", cover_id)

            elif (item.attrib.get("media-type", "") == "application/xhtml+xml" and
                    "nav" not in item.attrib.get("properties", "").split()):

                content_path = os.path.join(os.path.dirname(opf_path), item.attrib.get("href", ""))

                # get type based on the filename (might have to change in the future if we want to use other file naming conventions)
                epub_type = content_path.split("/")[-1].split("-")[-1].split(".")[0]
                types[item.attrib.get("id", None)] = epub_type

                with open(content_path) as f:
                    for line in f:
                        if "<math" in line or "<m:math" in line or "<math:math" in line:
                            properties.add("mathml")

                        if ("<script" in line or "<form" in line or "<button" in line or "<fieldset" in line or "<input" in line or
                                "<object" in line or "<output" in line or "<select" in line or "<textarea" in line):
                            properties.add("scripted")
                            # could also check for onclick attributes and similar, and should ideally ignore
                            # input elements if they have the type attribute is "image"

                        if "<svg" in line:
                            properties.add("svg")
                            # we could also check img/@src and iframe/@src for .svg files but it would require XML parsing or a regex.
                            # object elements could also contain SVG but are even more complex and probably very uncommon in the wild.

                        if "<epub:switch" in line:
                            properties.add("switch")
                            # this is deprecated in EPUB 3.2 but can be useful during production if we want to include for instance MusicXML

            if properties:
                properties = item.attrib.get("properties", "").split() + list(properties)  # add any preexisting properties
                properties = list(set(properties))  # only include unique properties
                item.attrib["properties"] = " ".join(properties)

        # reference the cover image from the metadata if it isn't already
        for meta in metadata:
            if meta.tag == "{http://www.idpf.org/2007/opf}meta" and meta.attrib.get("name", None) == "cover":
                cover_id = None
                break
        if cover_id is not None:
            meta = ElementTree.Element("{http://www.idpf.org/2007/opf}meta")
            meta.attrib["name"] = "cover"
            meta.attrib["content"] = cover_id
            metadata.append(meta)

        for itemref in spine:
            epub_type = types.get(itemref.attrib.get("idref", None))
            if epub_type in ["cover"]:  # add more types here if there's more we want to be regarded as secondary content (for instance footnotes?)
                itemref.attrib["linear"] = "no"

        serialized = '<?xml version="1.0" encoding="UTF-8"?>\n' + ElementTree.tostring(opf_element, pretty_print=True).decode('utf-8')

        with open(opf_path, "w") as f:
            f.write(serialized)

        return True

    @staticmethod
    def html_to_nav(pipeline, source, target):
        xslt = Xslt(pipeline,
                    stylesheet=os.path.join(Xslt.xslt_dir, Epub.uid, "html-to-nav.xsl"),
                    source=source,
                    target=target)
        return xslt

    @staticmethod
    def html_to_opf(pipeline, source, target):
        xslt = Xslt(pipeline,
                    stylesheet=os.path.join(Xslt.xslt_dir, Epub.uid, "html-to-opf.xsl"),
                    source=source,
                    target=target)
        return xslt

    @staticmethod
    def from_html(pipeline, dir_in, dir_out):
        assert os.path.isdir(dir_in)
        assert os.path.isdir(dir_out) or not os.path.exists(dir_out)

        epub_dir = os.path.join(dir_out, "EPUB")
        meta_dir = os.path.join(dir_out, "META-INF")
        os.makedirs(epub_dir)
        os.makedirs(meta_dir)

        # copy dir_in to dir_out/EPUB
        Filesystem.copytree(pipeline.utils.report, dir_in, epub_dir)

        # find html file
        html_file = None
        for root, dirs, files in os.walk(dir_out):
            for f in files:
                if f.endswith("xhtml"):
                    html_file = os.path.join(root, f)
        assert html_file, "There must be a file with the file extension '.xhtml' in the HTML fileset."

        # create dir_out/EPUB/package.opf based on input html (xslt)
        temp_opf_obj = tempfile.NamedTemporaryFile()
        temp_opf = temp_opf_obj.name
        contentref = None
        with open(temp_opf, "w") as opf:
            opf.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
            opf.write("<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\" xml:base=\"file://{}/\">\n".format(epub_dir))
            # <metadata> will be generated here using XSLT below
            opf.write("    <manifest>\n")
            opf.write("        <item media-type=\"application/xhtml+xml\" id=\"item_1\" href=\"nav.xhtml\" properties=\"nav\"/>\n")
            itempos = 2
            for root, dirs, files in os.walk(dir_out):
                files.sort()
                for f in files:
                    item_relative = os.path.relpath(os.path.join(root, f), epub_dir)
                    file_extension = os.path.split(item_relative)[-1].split(".")[-1].lower()
                    media_type = Epub.file_extensions[file_extension] if file_extension in Epub.file_extensions else "application/octet-stream"
                    if media_type == "application/xhtml+xml":
                        contentref = "item_" + str(itempos)
                    opf.write("        <item media-type=\"{}\" id=\"item_{}\" href=\"{}\"/>\n".format(media_type, itempos, item_relative))
                    itempos += 1
            opf.write("    </manifest>\n")
            opf.write("    <spine>\n")
            opf.write("        <itemref idref=\"{}\" id=\"itemref_1\"/>\n".format(contentref))
            opf.write("    </spine>\n")
            opf.write("</package>\n")

        if not contentref:
            pipeline.utils.report.info("Could not find content file...")
            return None

        xslt = Epub.html_to_opf(pipeline, temp_opf, os.path.join(epub_dir, "package.opf"))
        if not xslt.success:
            return None

        # create dir_out/EPUB/nav.xhtml based on input html (xslt)
        xslt = Epub.html_to_nav(pipeline, html_file, os.path.join(epub_dir, "nav.xhtml"))
        if not xslt.success:
            return None

        # add boilerplate dir_out/mediatype
        with open(os.path.join(dir_out, "mimetype"), "w") as mimetype:
            mimetype.write("application/epub+zip")

        # add boilerplate dir_out/META-INF/container.xml
        with open(os.path.join(meta_dir, "container.xml"), "w") as container:
            container.write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
            container.write("<container xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\" version=\"1.0\">\n")
            container.write("    <rootfiles>\n")
            container.write("        <rootfile full-path=\"EPUB/package.opf\" media-type=\"application/oebps-package+xml\"/>\n")
            container.write("    </rootfiles>\n")
            container.write("</container>\n")

        return Epub(pipeline.utils.report, dir_out)

    def copy(self):
        epub_tempfile_obj = tempfile.NamedTemporaryFile()
        epub_tempfile = epub_tempfile_obj.name
        Filesystem.copy(self.report, self.asFile(), epub_tempfile)
        return Epub(self.report, epub_tempfile), epub_tempfile_obj

    def fix_permissions(self):
        dir = self.asDir()
        for root, dirs, files in os.walk(dir):
            # read, write and execute on all directories
            for dir in dirs:
                os.chmod(os.path.join(root, dir),
                         stat.S_IRWXU | stat.S_IRWXG | stat.S_IRWXO)

            # read and write on all files
            for file in files:
                os.chmod(os.path.join(root, file),
                         stat.S_IRUSR | stat.S_IWUSR |
                         stat.S_IRGRP | stat.S_IWGRP |
                         stat.S_IROTH | stat.S_IWOTH)

        self.asFile(rebuild=True)  # make sure the permissions is included in the zipped version

    file_extensions = {
        "xml":       "application/xml",
        "xhtml":     "application/xhtml+xml",
        "smil":      "application/smil+xml",
        "mp3":       "audio/mpeg",
        "epub":      "application/epub+zip",
        "xpl":       "application/xproc+xml",
        "xproc":     "application/xproc+xml",
        "xsl":       "application/xslt+xml",
        "xslt":      "application/xslt+xml",
        "xq":        "application/xquery+xml",
        "xquery":    "application/xquery+xml",
        "otf":       "application/x-font-opentype",
        "ttf":       "application/x-font-ttf",
        "woff":      "application/font-woff",
        "eot":       "application/vnd.ms-fontobject",
        "wav":       "audio/x-wav",
        "opf":       "application/oebps-package+xml",
        "ncx":       "application/x-dtbncx+xml",
        "mp4":       "audio/mpeg4-generic",
        "jpg":       "image/jpeg",
        "jpe":       "image/jpeg",
        "jpeg":      "image/jpeg",
        "png":       "image/png",
        "svg":       "image/svg+xml",
        "css":       "text/css",
        "dtd":       "application/xml-dtd",
        "res":       "application/x-dtbresource+xml",
        "ogg":       "audio/ogg",
        "au":        "audio/basic",
        "snd":       "audio/basic",
        "mid":       "audio/mid",
        "rmi":       "audio/mid",
        "aif":       "audio/x-aiff",
        "aifc":      "audio/x-aiff",
        "aiff":      "audio/x-aiff",
        "m3u":       "audio/x-mpegurl",
        "ra":        "audio/x-pn-realaudio",
        "ram":       "audio/x-pn-realaudio",
        "bmp":       "image/bmp",
        "cod":       "image/cis-cod",
        "gif":       "image/gif",
        "ief":       "image/ief",
        "jfif":      "image/pipeg",
        "tif":       "image/tiff",
        "tiff":      "image/tiff",
        "ras":       "image/x-cmu-raster",
        "cmx":       "image/x-cmx",
        "ico":       "image/x-icon",
        "pnm":       "image/x-portable-anymap",
        "pbm":       "image/x-portable-bitmap",
        "pgm":       "image/x-portable-graymap",
        "ppm":       "image/x-portable-pixmap",
        "rgb":       "image/x-rgb",
        "xbm":       "image/x-xbitmap",
        "xpm":       "image/x-xpixmap",
        "xwd":       "image/x-xwindowdump",
        "mp2":       "video/mpeg",
        "mpa":       "video/mpeg",
        "mpe":       "video/mpeg",
        "mpeg":      "video/mpeg",
        "mpg":       "video/mpeg",
        "mpv2":      "video/mpeg",
        "mov":       "video/quicktime",
        "qt":        "video/quicktime",
        "lsf":       "video/x-la-asf",
        "lsx":       "video/x-la-asf",
        "asf":       "video/x-ms-asf",
        "asr":       "video/x-ms-asf",
        "asx":       "video/x-ms-asf",
        "avi":       "video/x-msvideo",
        "movie":     "video/x-sgi-movie",
        "323":       "text/h323",
        "htm":       "text/html",
        "html":      "text/html",
        "stm":       "text/html",
        "uls":       "text/iuls",
        "bas":       "text/plain",
        "c":         "text/plain",
        "h":         "text/plain",
        "txt":       "text/plain",
        "rtx":       "text/richtext",
        "sct":       "text/scriptlet",
        "tsv":       "text/tab-separated-values",
        "htt":       "text/webviewhtml",
        "htc":       "text/x-component",
        "etx":       "text/x-setext",
        "vcf":       "text/x-vcard",
        "mht":       "message/rfc822",
        "mhtml":     "message/rfc822",
        "nws":       "message/rfc822",
        "evy":       "application/envoy",
        "fif":       "application/fractals",
        "spl":       "application/futuresplash",
        "hta":       "application/hta",
        "acx":       "application/internet-property-stream",
        "hqx":       "application/mac-binhex40",
        "doc":       "application/msword",
        "dot":       "application/msword",
        "*":         "application/octet-stream",
        "bin":       "application/octet-stream",
        "class":     "application/octet-stream",
        "dms":       "application/octet-stream",
        "exe":       "application/octet-stream",
        "lha":       "application/octet-stream",
        "lzh":       "application/octet-stream",
        "oda":       "application/oda",
        "axs":       "application/olescript",
        "pdf":       "application/pdf",
        "prf":       "application/pics-rules",
        "p10":       "application/pkcs10",
        "crl":       "application/pkix-crl",
        "ai":        "application/postscript",
        "eps":       "application/postscript",
        "ps":        "application/postscript",
        "rtf":       "application/rtf",
        "setpay":    "application/set-payment-initiation",
        "setreg":    "application/set-registration-initiation",
        "xla":       "application/vnd.ms-excel",
        "xlc":       "application/vnd.ms-excel",
        "xlm":       "application/vnd.ms-excel",
        "xls":       "application/vnd.ms-excel",
        "xlt":       "application/vnd.ms-excel",
        "xlw":       "application/vnd.ms-excel",
        "msg":       "application/vnd.ms-outlook",
        "sst":       "application/vnd.ms-pkicertstore",
        "cat":       "application/vnd.ms-pkiseccat",
        "stl":       "application/vnd.ms-pkistl",
        "pot":       "application/vnd.ms-powerpoint",
        "pps":       "application/vnd.ms-powerpoint",
        "ppt":       "application/vnd.ms-powerpoint",
        "mpp":       "application/vnd.ms-project",
        "wcm":       "application/vnd.ms-works",
        "wdb":       "application/vnd.ms-works",
        "wks":       "application/vnd.ms-works",
        "wps":       "application/vnd.ms-works",
        "hlp":       "application/winhlp",
        "bcpio":     "application/x-bcpio",
        "cdf":       "application/x-cdf",
        "z":         "application/x-compress",
        "tgz":       "application/x-compressed",
        "cpio":      "application/x-cpio",
        "csh":       "application/x-csh",
        "dcr":       "application/x-director",
        "dir":       "application/x-director",
        "dxr":       "application/x-director",
        "dvi":       "application/x-dvi",
        "gtar":      "application/x-gtar",
        "gz":        "application/x-gzip",
        "hdf":       "application/x-hdf",
        "ins":       "application/x-internet-signup",
        "isp":       "application/x-internet-signup",
        "iii":       "application/x-iphone",
        "js":        "application/x-javascript",
        "latex":     "application/x-latex",
        "mdb":       "application/x-msaccess",
        "crd":       "application/x-mscardfile",
        "clp":       "application/x-msclip",
        "dll":       "application/x-msdownload",
        "m13":       "application/x-msmediaview",
        "m14":       "application/x-msmediaview",
        "mvb":       "application/x-msmediaview",
        "wmf":       "application/x-msmetafile",
        "mny":       "application/x-msmoney",
        "pub":       "application/x-mspublisher",
        "scd":       "application/x-msschedule",
        "trm":       "application/x-msterminal",
        "wri":       "application/x-mswrite",
        "nc":        "application/x-netcdf",
        "pma":       "application/x-perfmon",
        "pmc":       "application/x-perfmon",
        "pml":       "application/x-perfmon",
        "pmr":       "application/x-perfmon",
        "pmw":       "application/x-perfmon",
        "p12":       "application/x-pkcs12",
        "pfx":       "application/x-pkcs12",
        "p7b":       "application/x-pkcs7-certificates",
        "spc":       "application/x-pkcs7-certificates",
        "p7r":       "application/x-pkcs7-certreqresp",
        "p7c":       "application/x-pkcs7-mime",
        "p7m":       "application/x-pkcs7-mime",
        "p7s":       "application/x-pkcs7-signature",
        "sh":        "application/x-sh",
        "shar":      "application/x-shar",
        "swf":       "application/x-shockwave-flash",
        "sit":       "application/x-stuffit",
        "sv4cpio":   "application/x-sv4cpio",
        "sv4crc":    "application/x-sv4crc",
        "tar":       "application/x-tar",
        "tcl":       "application/x-tcl",
        "tex":       "application/x-tex",
        "texi":      "application/x-texinfo",
        "texinfo":   "application/x-texinfo",
        "roff":      "application/x-troff",
        "t":         "application/x-troff",
        "tr":        "application/x-troff",
        "man":       "application/x-troff-man",
        "me":        "application/x-troff-me",
        "ms":        "application/x-troff-ms",
        "ustar":     "application/x-ustar",
        "src":       "application/x-wais-source",
        "cer":       "application/x-x509-ca-cert",
        "crt":       "application/x-x509-ca-cert",
        "der":       "application/x-x509-ca-cert",
        "pko":       "application/ynd.ms-pkipko",
        "zip":       "application/zip",
        "flr":       "x-world/x-vrml",
        "vrml":      "x-world/x-vrml",
        "wrl":       "x-world/x-vrml",
        "wrz":       "x-world/x-vrml",
        "xaf":       "x-world/x-vrml",
        "xof":       "x-world/x-vrml",
        "gitignore": "text/plain",
        "hgignore":  "text/plain"
    }
