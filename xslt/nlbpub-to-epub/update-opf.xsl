<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:f="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:output indent="no" method="xml" exclude-result-prefixes="#all"/>

    <xsl:param name="contents" as="element()+"/>

    <xsl:template match="/">
        <xsl:variable name="spine-items-and-itemrefs" as="element()+">
            <xsl:call-template name="create-spine-items-and-itemrefs"/>
        </xsl:variable>

        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="copy"/>
            <xsl:call-template name="create-manifest">
                <xsl:with-param name="spine-items-and-itemrefs" select="$spine-items-and-itemrefs"/>
            </xsl:call-template>
            <xsl:call-template name="create-spine">
                <xsl:with-param name="spine-items-and-itemrefs" select="$spine-items-and-itemrefs"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="@* | node()" mode="copy" exclude-result-prefixes="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="copy"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="manifest | spine" mode="copy" exclude-result-prefixes="#all">
        <!-- Skip these, we'll create them ourselves -->
    </xsl:template>

    <xsl:template name="create-spine-items-and-itemrefs" as="element()+">
        <xsl:for-each select="$contents">
            <xsl:variable name="filename" select="replace(base-uri(), '^.*/([^/]+)$', '$1')" as="xs:string"/>
            <xsl:variable name="id" select="concat('item_', position())" as="xs:string"/>
            
            <item id="{$id}" media-type="application/xhtml+xml" href="{$filename}"/>
            <itemref idref="{$id}" id="itemref_{position()}"/>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="create-manifest" as="element()">
        <xsl:param name="spine-items-and-itemrefs" as="element()+"/>
        
        <manifest>
            <xsl:copy-of select="manifest/@*" exclude-result-prefixes="#all"/>
            
            <!-- Preserve items that are:
                 1. Navigation items (properties="nav")
                 2. Not in the spine (CSS, fonts, etc.)
                 3. Referenced in HTML content (images, etc.)
            -->
            <xsl:for-each select="manifest/item">
                <xsl:variable name="item-id" select="@id" as="xs:string"/>
                <xsl:variable name="item-href" select="@href" as="xs:string"/>
                
                <xsl:if test="tokenize(@properties, '\s+') = 'nav' 
                           or not(../../spine/itemref/@idref = $item-id)
                           or f:is-referenced-in-content($item-href)">
                    <xsl:call-template name="newline-indent"/>
                    <xsl:element name="{name()}">
                        <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                    </xsl:element>
                </xsl:if>
            </xsl:for-each>
            
            <xsl:for-each select="$spine-items-and-itemrefs[self::item]">
                <xsl:call-template name="newline-indent"/>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:for-each>
        </manifest>
    </xsl:template>

    <!-- Function to check if a resource is referenced in HTML content -->
    <xsl:function name="f:is-referenced-in-content" as="xs:boolean">
        <xsl:param name="href" as="xs:string"/>
        
        <!-- Check for image references in img src attributes -->
        <xsl:variable name="img-references" as="xs:boolean">
            <xsl:value-of select="exists($contents//html:img/@src[. = $href or . = concat('images/', $href) or . = concat('css/', $href) or . = concat('fonts/', $href)])"/>
        </xsl:variable>
        
        <!-- Check for CSS references in link href attributes -->
        <xsl:variable name="css-references" as="xs:boolean">
            <xsl:value-of select="exists($contents//html:link[@rel='stylesheet']/@href[. = $href or . = concat('css/', $href)])"/>
        </xsl:variable>
        
        <!-- Check for font references in CSS @font-face -->
        <xsl:variable name="font-references" as="xs:boolean">
            <xsl:value-of select="exists($contents//html:style[contains(text(), $href)])"/>
        </xsl:variable>
        
        <!-- Check for other resource references -->
        <xsl:variable name="other-references" as="xs:boolean">
            <xsl:value-of select="exists($contents//@*[contains(., $href)])"/>
        </xsl:variable>
        
        <xsl:value-of select="$img-references = true() or $css-references = true() or $font-references = true() or $other-references = true()"/>
    </xsl:function>

    <xsl:template name="create-spine" as="element()">
        <xsl:param name="spine-items-and-itemrefs" as="element()+"/>
        <spine>
            <xsl:for-each select="$spine-items-and-itemrefs[self::itemref]">
                <xsl:call-template name="newline-indent"/>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:for-each>
            
            <xsl:call-template name="newline-indent"><xsl:with-param name="indent" select="1"/></xsl:call-template>
        </spine>
    </xsl:template>

    <xsl:template name="create-metadata" as="element()">
        <xsl:param name="manifest" as="element()"/>
        <xsl:param name="spine" as="element()"/>
        <xsl:copy-of select="metadata" exclude-result-prefixes="#all"/>
    </xsl:template>

    <xsl:template name="newline-indent">
        <xsl:param name="indent" select="2" as="xs:integer"/>  <!-- use 2 indents as default, as that's what we commmonly want in a OPF -->
        
        <!-- newline -->
        <xsl:text>
</xsl:text>
        
        <!-- indents -->
        <xsl:for-each select="1 to $indent">
            <xsl:text>    </xsl:text>
        </xsl:for-each>
    </xsl:template>

    <xsl:function name="f:matters" as="xs:string+">
        <xsl:param name="contents" as="element()+"/>
        
        <xsl:variable name="matters" as="xs:string+">
            <xsl:for-each select="$contents">
                <xsl:variable name="from-section-start" select="(html:body/html:*[tokenize(@class, '\s+') = 'section-start'])[1]" as="element()?"/>
                <xsl:variable name="from-section-start" select="$from-section-start/tokenize(@epub:type, '\s+')[. = ('cover', 'frontmatter', 'bodymatter', 'backmatter')]" as="xs:string*"/>
                
                <xsl:variable name="from-filename" select="if (matches(base-uri(), '^.*/[^-]+-\d+-[a-z-]+.xhtml$')) then replace(base-uri(), '^.*/[^-]+-\d+-([a-z-]+).xhtml$', '$1') else ()" as="xs:string?"/>
                <xsl:variable name="from-filename" select="if ($from-filename = ('cover', 'frontmatter', 'bodymatter', 'backmatter')) then $from-filename else ()" as="xs:string?"/>
                
                <xsl:choose>
                    <xsl:when test="count($from-section-start) gt 0">
                        <xsl:value-of select="$from-section-start[1]"/>
                    </xsl:when>
                    <xsl:when test="$from-filename">
                        <xsl:value-of select="$from-filename"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="'unknown'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:for-each select="$matters">
            <xsl:variable name="position" select="position()" as="xs:integer"/>
            
            <xsl:choose>
                <xsl:when test=". != 'unknown'">
                    <xsl:value-of select="."/>
                </xsl:when>
                <xsl:when test="$matters[position() lt $position] = 'backmatter'">
                    <xsl:value-of select="'backmatter'"/>
                </xsl:when>
                <xsl:when test="$matters[position() lt $position] = 'bodymatter'">
                    <xsl:value-of select="'bodymatter'"/>
                </xsl:when>
                <xsl:when test="$matters[position() lt $position] = 'frontmatter'">
                    <xsl:value-of select="'frontmatter'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'cover'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

</xsl:stylesheet>
