#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Validator for MathML, used in NLBs (X)HTML5 documents.

This script is based on NLBs internal validator used for MathML.
This is a standalone version of code used in a bigger system,
and so this standalone version is not well tested.
It is privided for convenience and is not normative.
Rules may be added or updated in the future.

If you have questions about how to run this script,
please contact NLBs developers at utviklere@nlb.no.

Requirements:
- lxml (pip3 install lxml)

Version: 2020-07-08

Copyright (c) 2020 NLB

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

import logging
import os
import sys

from lxml import etree

if sys.version_info[0] != 3 or sys.version_info[1] < 6:
    print("# This script requires Python version 3.6+")
    sys.exit(1)

nsmap = {
    'epub': 'http://www.idpf.org/2007/ops',
    'm': "http://www.w3.org/1998/Math/MathML",
    None: 'http://www.w3.org/1999/xhtml',
    'xml': "http://www.w3.org/XML/1998/namespace"
}


def validate(path, oneline=False):
    """Validate a XHTML file."""
    try:
        success = True
        error_count = 0
        filename = os.path.basename(path)

        if not os.path.isfile(path):
            logging.error(f"{filename} - File does not exist: {path}")
            return False

        tree = etree.parse(path)
        root = tree.getroot()

        asciimath_elements = root.findall(".//*[@class='asciimath']", nsmap)
        if len(asciimath_elements) >= 1:
            logging.warning("This document may contain asciimath. This should be investigated")

        mathML_elements = root.findall(".//m:math", nsmap)
        if len(mathML_elements) == 0:
            mathML_elements = root.findall(".//math", nsmap)

        if len(mathML_elements) == 0:
            logging.info(f"{filename} - No <math> elements found " +
                         "in the document.")
            return True

        for element in mathML_elements:
            element_success = True

            parent = element.getparent()
            include_parent_in_log = False

            if etree.QName(parent).localname == "p":
                if (element.getprevious() is None and
                        element.getnext() is None and
                        parent.text is None):
                    if element.tail is None or element.tail.isspace():
                        element_success = False
                        logging.error(
                            f"{filename}:{element.sourceline} - " +
                            "A <math> element cannot be the only element " +
                            "inside a <p>. Instead of " +
                            "<p><math display=\"inline\">…</math></p>, " +
                            "please use <math display=\"block\">…</math>."
                        )
                        include_parent_in_log = True

            if "altimg" not in element.attrib:
                element_success = False
                logging.error(f"{filename}:{element.sourceline} - " +
                              "The <math> element does not contain " +
                              "the required attribute \"altimg\".")

            if "alttext" not in element.attrib:
                element_success = False
                logging.error(f"{filename}:{element.sourceline} - " +
                              "The <math> element does not contain " +
                              "the required attribute \"alttext\".")

            alttext = element.attrib["alttext"]
            if len(alttext) <= 1 and len(etree.tostring(element, encoding='unicode', method='xml', with_tail=False)) >= 275 or len(alttext) == 0:
                element_success = False
                logging.error(f"{filename}:{element.sourceline} - " +
                              "The <math> element does not contain " +
                              "a correct \"alttext\".")

            if "display" not in element.attrib:
                element_success = False
                logging.error(f"{filename}:{element.sourceline} - " +
                              "The <math> element does not contain " +
                              "the required attribute \"display\".")

            else:
                display_attrib = element.attrib["display"]
                suggested_display_attribute = inline_or_block(element, parent)
                if display_attrib != suggested_display_attribute:
                    element_success = False
                    logging.error(
                        f"{filename}:{element.sourceline} - " +
                        "The <math> element has " +
                        "the wrong display attribute. " +
                        f"display=\"{display_attrib}\" should be " +
                        f"display=\"{suggested_display_attribute}\"."
                    )
                    include_parent_in_log = True

            if not element_success:
                error_count += 1
                success = False
                if not oneline:
                    log_element = parent if include_parent_in_log else element
                    logging.info(etree.tostring(log_element,
                                                encoding='unicode',
                                                method='xml',
                                                with_tail=False))
                    logging.info("")

        if success is True:
            logging.info(f"{filename} - No errors found " +
                         "during MathML validation")
        else:
            logging.error(f"{filename} - {error_count} errors found " +
                          "during MathML validation.")

        return success

    except Exception:
        logging.exception("An error occured during MathML validation.")
        return False


def inline_or_block(element, parent, check_siblings=True):
    """Try to determine if we're in a inline context or a block context."""
    flow_tags = ["figcaption", "dd", "li", "caption", "th", "td", "p"]
    inline_elements = ["a", "abbr", "bdo", "br", "code", "dfn", "em", "img",
                       "kbd", "q", "samp", "span", "strong", "sub", "sup"]

    parent_text = parent.text
    sibling_text_not_empty = False
    sibling_is_inline = False
    parent_is_inline = False

    if check_siblings:

        for elem in list(parent):
            if elem.tail is not None and elem.tail.isspace() is not True:
                sibling_is_inline = True

        if parent_text is not None and parent_text.isspace() is not True:
            sibling_text_not_empty = True

        elif element.tail is not None and element.tail.isspace() is not True:
            sibling_text_not_empty = True

        for inline_element in inline_elements:
            inline_elements_in_element = parent.findall(inline_element, nsmap)
            if len(inline_elements_in_element) > 0:
                sibling_is_inline = True

    if parent.getparent() is not None:
        parent_display = inline_or_block(parent,
                                         parent.getparent(),
                                         check_siblings=False)
        if parent_display == "inline":
            parent_is_inline = True

    if sibling_is_inline or sibling_text_not_empty or parent_is_inline:
        return "inline"

    if etree.QName(parent).localname in flow_tags:
        if element.getprevious() is not None or element.getnext() is not None:
            return "block"
        else:
            return "inline"

    return "block"


if __name__ == "__main__":
    oneline = len(sys.argv) >= 3 and "oneline" in sys.argv[2:]

    logging.basicConfig(stream=sys.stdout,
                        level=logging.INFO,
                        format="%(message)s")

    if len(sys.argv) <= 1:
        logging.info("""
Usage:
  ./nlb_mathml_validator.py <path-to-xhtml-file>

One line per error:
  ./nlb_mathml_validator.py <path-to-xhtml-file> oneline
""")

    file = sys.argv[1]
    path = os.path.abspath(file)
    success = validate(path, oneline=oneline)
    logging.info("Success" if success else "Failed")
    sys.exit(0 if success else 1)
