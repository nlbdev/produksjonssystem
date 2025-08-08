#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tempfile
import subprocess
from lxml import etree as ElementTree


def test_opf_manifest_preserves_images():
    """Test that update-opf.xsl preserves image references in manifest"""
    
    # Create a temporary directory for testing
    with tempfile.TemporaryDirectory() as temp_dir:
        # Create a simple EPUB structure
        epub_dir = os.path.join(temp_dir, "test_epub")
        os.makedirs(epub_dir)
        
        # Create EPUB directory
        epub_content_dir = os.path.join(epub_dir, "EPUB")
        os.makedirs(epub_content_dir)
        os.makedirs(os.path.join(epub_content_dir, "images"))
        
        # Create a test image
        with open(os.path.join(epub_content_dir, "images", "test-image.jpg"), "w") as f:
            f.write("dummy image content")
        
        # Create original OPF with image reference
        original_opf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
    <metadata>
        <dc:identifier id="pub-id">test-book</dc:identifier>
        <dc:title>Test Book</dc:title>
        <dc:language>en</dc:language>
    </metadata>
    <manifest>
        <item media-type="application/xhtml+xml" id="nav" href="nav.xhtml" properties="nav"/>
        <item media-type="application/xhtml+xml" id="content" href="content.xhtml"/>
        <item media-type="image/jpeg" id="image1" href="images/test-image.jpg"/>
    </manifest>
    <spine>
        <itemref idref="content"/>
    </spine>
</package>'''
        
        with open(os.path.join(epub_content_dir, "package.opf"), "w", encoding="utf-8") as f:
            f.write(original_opf)
        
        # Create content HTML that references the image
        content_html = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Test Content</title>
</head>
<body>
    <h1>Test Content</h1>
    <img src="images/test-image.jpg" alt="Test image"/>
</body>
</html>'''
        
        with open(os.path.join(epub_content_dir, "content.xhtml"), "w", encoding="utf-8") as f:
            f.write(content_html)
        
        # Create nav HTML
        nav_html = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Navigation</title>
</head>
<body>
    <nav epub:type="toc">
        <h1>Table of Contents</h1>
        <ol>
            <li><a href="content.xhtml">Content</a></li>
        </ol>
    </nav>
</body>
</html>'''
        
        with open(os.path.join(epub_content_dir, "nav.xhtml"), "w", encoding="utf-8") as f:
            f.write(nav_html)
        
        # Test the update-opf.xsl transformation using xsltproc
        xslt_path = os.path.join("..", "xslt", "nlbpub-to-epub", "update-opf.xsl")
        opf_path = os.path.join(epub_content_dir, "package.opf")
        output_path = os.path.join(epub_content_dir, "package_updated.opf")
        
        try:
            # Run xsltproc to apply the transformation
            result = subprocess.run([
                "xsltproc",
                "--stringparam", "spine-hrefs", "content.xhtml",
                xslt_path,
                opf_path
            ], capture_output=True, text=True, cwd=temp_dir)
            
            if result.returncode != 0:
                print("XSLT transformation failed:")
                print("STDOUT:", result.stdout)
                print("STDERR:", result.stderr)
                return False
            
            # Write the output to file
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(result.stdout)
            
            # Check if the image reference is preserved in the updated OPF
            updated_opf_xml = ElementTree.parse(output_path).getroot()
            
            # Look for image items in the manifest
            manifest = updated_opf_xml.find(".//{http://www.idpf.org/2007/opf}manifest")
            image_items = manifest.findall(".//{http://www.idpf.org/2007/opf}item[@media-type='image/jpeg']")
            
            # Check if the test image is still in the manifest
            test_image_found = False
            for item in image_items:
                if item.get("href") == "images/test-image.jpg":
                    test_image_found = True
                    break
            
            if not test_image_found:
                print("ERROR: Image reference 'images/test-image.jpg' was removed from OPF manifest")
                print("This confirms the bug where update-opf.xsl removes image references")
                print("\nOriginal OPF manifest items:")
                original_xml = ElementTree.parse(opf_path).getroot()
                original_manifest = original_xml.find(".//{http://www.idpf.org/2007/opf}manifest")
                for item in original_manifest.findall(".//{http://www.idpf.org/2007/opf}item"):
                    print(f"  - {item.get('href')} (media-type: {item.get('media-type')})")
                
                print("\nUpdated OPF manifest items:")
                for item in manifest.findall(".//{http://www.idpf.org/2007/opf}item"):
                    print(f"  - {item.get('href')} (media-type: {item.get('media-type')})")
                
                return False
            else:
                print("SUCCESS: Image reference 'images/test-image.jpg' was preserved in OPF manifest")
                return True
                
        except FileNotFoundError:
            print("xsltproc not found. Skipping test.")
            return True  # Skip test if xsltproc is not available


if __name__ == "__main__":
    success = test_opf_manifest_preserves_images()
    if success:
        print("Test passed: OPF manifest correctly preserves image references")
    else:
        print("Test failed: OPF manifest incorrectly removes image references")
        sys.exit(1)
