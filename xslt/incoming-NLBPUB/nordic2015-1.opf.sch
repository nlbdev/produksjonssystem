<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt2">

    <title>Nordic EPUB3 Package Document rules</title>

    <ns prefix="opf" uri="http://www.idpf.org/2007/opf"/>
    <ns prefix="dc" uri="http://purl.org/dc/elements/1.1/"/>
    <ns prefix="epub" uri="http://www.idpf.org/2007/ops"/>
    <ns prefix="nordic" uri="http://www.mtm.se/epub/"/>

    <pattern id="opf_nordic_1">
        <rule context="/*">
            <assert test="ends-with(base-uri(/*),'.opf')">[opf1] the OPF file must have the extension .opf</assert>
            <assert test="matches(base-uri(/*),'.*/package.opf')">[opf1] the filename of the OPF must be package.opf</assert>
            <assert test="matches(base-uri(/*),'EPUB/package.opf')">[opf1] the OPF must be contained in a folder named EPUB</assert>
        </rule>
    </pattern>

    <pattern id="opf_nordic_2">
        <rule context="opf:package">
            <assert test="@version = '3.0'">[opf2] the version attribute must be 3.0</assert>
            <assert test="@unique-identifier = 'pub-identifier'">[opf2] on the package element; the unique-identifier-attribute must be present and equal 'pub-identifier'</assert>
            <assert test="namespace-uri-for-prefix('dc',.) = 'http://purl.org/dc/elements/1.1/'">[opf2] on the package element; the dublin core namespace (xmlns:dc="http://purl.org/dc/elements/1.1/")
                must be declared on the package element</assert>
            <assert test="not(exists(opf:metadata/opf:meta[starts-with(@property,'nordic:')])) or matches(@prefix, '(^|\s)nordic: http://www.mtm.se/epub/(\s|$)')">[opf2] if the "nordic" prefix is used in the metadata, then the prefix attribute on the package element must declare the nordic metadata namespace (prefix="nordic:
                http://www.mtm.se/epub/")</assert>
            <assert test="not(exists(opf:metadata/opf:meta[starts-with(@property,'nlb:')])) or matches(@prefix, '(^|\s)nlb: http://www.nlb.no/epub/(\s|$)')">[opf2] if the "nlb" prefix is used in the metadata, then the prefix attribute on the package element must declare the nlb EPUB metadata namespace (prefix="nlb:
                http://www.nlb.no/epub/")</assert>
        </rule>
    </pattern>

    <pattern>
        <rule context="dc:language[not(@refines)]">
            <assert test="matches(text(), '^[a-z][a-z](-[A-Z][A-Z])?$')">[opf3c] the language code ("<value-of
                select="text()"/>") must be either a "two-letter lower case" code or a "two-letter lower case + hyphen + two-letter upper case" code.</assert>
        </rule>
    </pattern>

    <pattern id="opf_nordic_3">
        <rule context="opf:metadata">
            <assert test="count(dc:identifier[not(@refines)]) = 1">[opf3a] there must be exactly one dc:identifier element (without a refines attribute)</assert>
            <assert test="parent::opf:package/@unique-identifier = dc:identifier[not(@refines)]/@id">[opf3a] the id of the dc:identifier (without a refines attribute) must equal the value of the package elements unique-identifier
                attribute</assert>
            <assert test="count(dc:identifier) = 1 and matches(dc:identifier/text(),'^[A-Za-z0-9].*$')">[opf3a] The identifier ("<value-of select="dc:identifier/text()"/>") must start with a upper- or
                lower-case letter (A-Z or a-z), or a digit (0-9).</assert>
            <assert test="count(dc:identifier) = 1 and matches(dc:identifier/text(),'^.*[A-Za-z0-9]$')">[opf3a] The identifier ("<value-of select="dc:identifier/text()"/>") must end with a upper- or
                lower-case letter (A-Z or a-z), or a digit (0-9).</assert>
            <assert test="count(dc:identifier) = 1 and matches(dc:identifier/text(),'^[A-Za-z0-9_-]*$')">[opf3a] The identifier ("<value-of select="dc:identifier/text()"/>") must only contain upper-
                or lower-case letters (A-Z or a-z), digits (0-9), dashes (-) and underscores (_).</assert>

            <assert test="count(dc:title[not(@refines)]) = 1">[opf3b] exactly one dc:title <value-of select="if (dc:title[@refines]) then '(without a &quot;refines&quot; attribute)' else ''"/> must be
                present in the package document.</assert>
            <assert test="string-length(normalize-space(dc:title[not(@refines)]/text()))">[opf3b] the dc:title <value-of
                    select="if (dc:title[@refines]) then '(without a &quot;refines&quot; attribute)' else ''"/> must not be empty.</assert>

            <assert test="count(dc:language[not(@refines)]) ge 1">[opf3c] at least one dc:language <value-of select="if (dc:language[@refines]) then '(without a &quot;refines&quot; attribute)' else ''"
                /> must be present in the package document.</assert>
            
            <assert test="count(dc:date[not(@refines)]) = 1">[opf3d] exactly one dc:date <value-of select="if (dc:date[@refines]) then '(without a &quot;refines&quot; attribute)' else ''"/> must be
                present</assert>
            <assert test="count(dc:date[not(@refines)]) = 1 and matches(dc:date[not(@refines)], '\d\d\d\d-\d\d-\d\d')">[opf3d] the dc:date (<value-of select="dc:date/text()"/>) must be of the format
                YYYY-MM-DD (year-month-day)</assert>

            <assert test="count(dc:publisher[not(@refines)]) = 1">[opf3e] exactly one dc:publisher <value-of
                    select="if (dc:publisher[@refines]) then '(without a &quot;refines&quot; attribute)' else ''"/> must be present</assert>
            <assert test="count(dc:publisher[not(@refines)]) = 1 and dc:publisher[not(@refines)]/normalize-space(text())">[opf3e] the dc:publisher cannot be empty</assert>
            
            <assert test="count(opf:meta[@property='nlb:guidelines' and not(@refines)]) = 1">[opf3i] there must be exactly one meta element with the property "nlb:guidelines" <value-of
                    select="if (opf:meta[@property='nlb:guidelines' and @refines]) then '(without a &quot;refines&quot; attribute)' else ''"/></assert>
            <assert test="opf:meta[@property='nlb:guidelines' and not(@refines)] = '2018-1'">[opf3i] the value of nlb:guidelines must be '2018-1'</assert>

            <assert test="count(opf:meta[@property='nlb:supplier' and not(@refines)]) = 1">[opf3j] there must be exactly one meta element with the property "nlb:supplier" <value-of
                    select="if (opf:meta[@property='nlb:supplier' and @refines]) then '(without a &quot;refines&quot; attribute)' else ''"/></assert>
        </rule>
    </pattern>

    <pattern id="opf_nordic_5_a">
        <rule context="opf:manifest">
            <report test="opf:item[@media-type='application/x-dtbncx+xml']">[opf5a] a NCX must not be present in the manifest (media-type="application/x-dtbncx+xml")</report>
        </rule>
    </pattern>

    <pattern id="opf_nordic_7">
        <rule context="opf:item[@media-type='application/xhtml+xml' and tokenize(@properties,'\s+')='nav']">
            <assert test="@href = 'nav.xhtml'">[opf7] the Navigation Document must be located in the same directory as the package document, and must be named 'nav.xhtml' (not "<value-of
                    select="@href"/>")</assert>
        </rule>
    </pattern>
    
    <pattern>
        <rule context="opf:item[@media-type != 'application/xhtml+xml']">
            <assert test="contains(@href,'/')">All non-XHTML resources (such as images and CSS stylesheets) must be placed in subdirectories.
                The <value-of select="if (starts-with(@media-type,'application/')) then @media-type else replace(@media-type,'/.*','')"/> file
                "<value-of select="replace(@href,'.*/','')"/>" is located in "<value-of select="replace(@href,'[^/]+$','')"/>"</assert>
        </rule>
    </pattern>
    
    <pattern>
        <rule context="opf:item[@media-type = 'application/xhtml+xml']">
            <report test="contains(@href,'/')">All XHTML resources must not be placed in subdirectories. The XHTML file
                "<value-of select="replace(@href,'.*/','')"/>" is located in "<value-of select="replace(@href,'[^/]+$','')"/>"</report>
        </rule>
    </pattern>

    <pattern id="opf_nordic_12_a">
        <rule context="opf:item[@media-type='application/xhtml+xml' and not(@href='nav.xhtml' or tokenize(@properties,'\s+')='nav')]">
            <assert test="@href = concat(/opf:package/opf:metadata/dc:identifier[not(@refines)]/text(), '.xhtml')">[opf12a] The content document "<value-of select="@href"/>" has an illegal filename.
                The filename must be: "<value-of select="concat(/opf:package/opf:metadata/dc:identifier[not(@refines)]/text(), '.xhtml')"/>".</assert>
        </rule>
    </pattern>

    <pattern id="opf_nordic_13">
        <rule context="opf:item[@media-type='application/xhtml+xml' and @href='nav.xhtml']">
            <assert test="tokenize(@properties,'\s+')='nav'">[opf13] the Navigation Document must be identified with the attribute properties="nav" in the OPF manifest. It currently <value-of
                    select="if (not(@properties)) then 'does not have a &quot;properties&quot; attribute' else concat('has the properties: ',string-join(tokenize(@properties,'\s+'),', '),', but not &quot;nav&quot;')"
                /></assert>
        </rule>
    </pattern>

    <pattern id="opf_nordic_14">
        <rule context="opf:itemref">
            <let name="itemref" value="."/>
            <report test="count(//opf:item[@id=$itemref/@idref and (tokenize(@properties,'\s+')='nav' or @href='nav.xhtml')])">[opf14] the Navigation Document must not be present in the OPF spine
                (itemref with idref="<value-of select="@idref"/>").</report>
        </rule>
    </pattern>

    <pattern id="opf_nordic_15_a">
        <rule context="opf:item[starts-with(@media-type,'image/') and matches(@href, '.*/cover.[^/]*$')]">
            <assert test="tokenize(@properties,'\s+') = 'cover-image'">[opf15a] The cover image must have a properties attribute containing the value 'cover-image': <value-of
                    select="concat('&lt;',name(),string-join(for $a in (@*) return concat(' ',$a/name(),'=&quot;',$a,'&quot;'),''),'&gt;')"/></assert>
        </rule>
    </pattern>
    
</schema>
