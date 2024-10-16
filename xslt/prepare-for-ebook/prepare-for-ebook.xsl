<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">

    <xsl:import href="fulltekst-maler.xsl"/>

    <xsl:output method="xhtml" indent="no" include-content-type="no" exclude-result-prefixes="#all"/>

    <xsl:param name="modified" as="xs:string?"/>

    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:function name="f:classes" as="xs:string*">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@class,'\s+')"/>
    </xsl:function>

    <!-- update modification time and insert CSS stylesheet -->
    <xsl:template match="head">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <meta name="dcterms:modified" content="{if ($modified) then $modified else format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]-[M00]-[D00]T[H00]:[m00]:[s00]Z')}"/>
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <link rel="stylesheet" type="text/css" href="ebok.css"/>
            <xsl:text><![CDATA[
    ]]></xsl:text>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="meta[@name='dcterms:modified']"/>

    <!-- insert copyright and usage information right after the titlepage -->
    <xsl:template match="section[tokenize(@epub:type,'\s+') = 'titlepage']">
        <xsl:next-match/>
        
        <xsl:call-template name="copyright-page"/>
        <xsl:call-template name="info-om-boka"/>
    </xsl:template>
    
    <!-- if there's no titlepage, insert copyright and usage information as the first frontmatter -->
    <xsl:template match="body/section[not(tokenize(@epub:type, '\s+') = ('cover', 'titlepage'))][1]">
        <xsl:if test="not(exists(../section[tokenize(@epub:type,'\s+') = 'titlepage']))">
            <xsl:call-template name="copyright-page"/>
            <xsl:call-template name="info-om-boka"/>
        </xsl:if>
        
        <xsl:next-match/>
    </xsl:template>

    <!-- make page numbers visible -->
    <xsl:template match="*[tokenize(@epub:type,'\s+')='pagebreak']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @title"/>

            <xsl:variable name="language" select="(ancestor-or-self::*/(@xml:lang/string(.), @lang/string(.)), /*/head/meta[@name='dc:language']/@content/string(.))[1]" as="xs:string"/>
            <xsl:choose>
                <xsl:when test="$language = 'en' or starts-with($language, 'en-')">
                    <xsl:text>Page </xsl:text>
                    <xsl:value-of select="@title"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Side </xsl:text>
                    <xsl:value-of select="@title"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>

    <!-- p is not allowed in captions -->
    <xsl:template match="caption/p">
        <span>
            <xsl:apply-templates select="@* | node()"/>
        </span>
        <xsl:if test="following-sibling::*">
            <br/>
        </xsl:if>
    </xsl:template>
    
    <!-- make it possible to reference hidden headlines -->
    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6">
        <xsl:variable name="whitespace" select="concat('&#xA;', string-join(for $a in (ancestor::*) return '    ', ''))"/>
        
        <xsl:choose>
            <xsl:when test="(preceding-sibling::div[1] intersect preceding-sibling::*[1])[tokenize(@class, '\s+') = 'hidden-headline-anchor']">
                <!-- hidden-headline-anchor already present: copy the headline as it is -->
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:apply-templates select="@*"/>
                    <xsl:apply-templates select="node()"/>
                </xsl:copy>
            </xsl:when>
            
            <xsl:when test="f:classes(.)='hidden-headline' and not(@id)">
                <!-- if this is a hidden headline, create a hidden-headline anchor -->
                <xsl:variable name="id" select="if (@id) then @id else concat('generated-headline-', generate-id())"/>
                <div id="{$id}" class="hidden-headline-anchor"></div>
                <xsl:value-of select="$whitespace"/>
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:apply-templates select="@* except @id"/>
                    <xsl:apply-templates select="node()"/>
                </xsl:copy>
            </xsl:when>
            
            <xsl:otherwise>
                <!-- copy as it is, but make sure that the headline has an id attribute -->
                <xsl:variable name="id" select="if (@id) then @id else concat('generated-headline-', generate-id())"/>
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:apply-templates select="@*"/>
                    <xsl:attribute name="id" select="$id"/>
                    <xsl:apply-templates select="node()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
