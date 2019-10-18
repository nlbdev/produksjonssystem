<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns:epub="http://www.idpf.org/2007/ops"
                exclude-result-prefixes="#all"
                xmlns:f="#"
                version="2.0">
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section[not(exists(h1 | h2 | h3 | h4 | h5 | h6)) and not(ancestor-or-self::section/f:types(.) = 'cover')]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            
            <xsl:variable name="level" select="count(ancestor-or-self::section)"/>
            <xsl:variable name="hx" select="concat('h', min((6, $level)))" as="xs:string"/>
            <xsl:variable name="chapter-headline" select="f:chapter-headline(.)" as="xs:string"/>
            
            <xsl:element name="{$hx}" namespace="http://www.w3.org/1999/xhtml">
                <xsl:attribute name="id" select="generate-id(.)"/>
                <xsl:attribute name="class" select="'generated-headline hidden-headline'"/>
                <xsl:value-of select="$chapter-headline"/>
            </xsl:element>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:function name="f:chapter-headline" as="xs:string">
        <xsl:param name="section" as="element()"/>
        
        <xsl:variable name="matter" select="for $type in ($section/ancestor-or-self::section[last()]/f:types(.)) return (if ($type = ('cover', 'frontmatter', 'bodymatter', 'backmatter')) then $type else ())" as="xs:string*"/>
        <xsl:variable name="matter" select="($matter, 'bodymatter')[1]" as="xs:string"/>
        
        <xsl:choose>
            <!-- part -->
            <xsl:when test="$section/f:types(.) = 'part'">
                <xsl:value-of select="concat(f:chapter-translation('part', $section), ' ', count($section/preceding-sibling::section[f:types(.) = $matter and f:types(.) = 'part']) + 1)"/>
            </xsl:when>
            
            <!-- subchapters -->
            <xsl:when test="exists($section/ancestor::section) and not($section/ancestor::section[1]/f:types(.) = 'part')">
                <xsl:variable name="position" select="count($section/preceding-sibling::section) + 1" as="xs:integer"/>
                <xsl:variable name="parent-position" select="f:chapter-headline($section/ancestor::section[1])" as="xs:string"/>
                <xsl:value-of select="concat($parent-position, '.', $position)"/>
            </xsl:when>
            
            <!-- top-level chapters -->
            <xsl:when test="not(exists($section/ancestor::section))">
                <xsl:variable name="result" select="concat(f:chapter-translation($matter, $section), ' ')"/>
                <xsl:value-of select="concat($result, count($section/preceding-sibling::section[f:types(.) = $matter]/(if (f:types(.) = 'part') then section else .)) + 1)"/>
            </xsl:when>
            
            <!-- chapters in parts -->
            <xsl:otherwise>
                <xsl:variable name="result" select="concat(f:chapter-translation($matter, $section), ' ')"/>
                <xsl:value-of select="concat($result, count($section/preceding-sibling::section | $section/ancestor::section[1]/preceding-sibling::section[f:types(.) = $matter]/(if (f:types(.) = 'part') then section else .)) + 1)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="f:types" as="xs:string*">
        <xsl:param name="context" as="element()"/>
        <xsl:sequence select="$context/tokenize(@epub:type, '\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:chapter-translation">
        <xsl:param name="matter" as="xs:string"/>
        <xsl:param name="section" as="element()"/>
        
        <xsl:variable name="language" select="($section/ancestor-or-self::*/@xml:lang)[last()]" as="xs:string"/>
        
        <xsl:variable name="translations" as="element()*">
            <cover>
                <en>Cover</en>
                <no>Omslag</no>
                <nb>Omslag</nb>
                <nn>Omslag</nn>
            </cover>
            <frontmatter>
                <en>Frontmatter</en>
                <no>Frontmaterie</no>
                <nb>Frontmaterie</nb>
                <nn>Frontmaterie</nn>
            </frontmatter>
            <bodymatter>
                <en>Chapter</en>
                <no>Kapittel</no>
                <nb>Kapittel</nb>
                <nn>Kapittel</nn>
            </bodymatter>
            <backmatter>
                <en>Backmatter</en>
                <no>Sluttmaterie</no>
                <nb>Sluttmaterie</nb>
                <nn>Sluttmaterie</nn>
            </backmatter>
            <part>
                <en>Part</en>
                <no>Del</no>
                <nb>Del</nb>
                <nn>Del</nn>
            </part>
        </xsl:variable>
        
        <xsl:value-of select="(
            $translations[local-name() = $matter]/*[local-name() = $language]/text(),
            $translations[local-name() = $matter]/*:no/text(),
            $translations[local-name() = 'bodymatter']/*[local-name() = $language]/text(),
            $translations[local-name() = 'bodymatter']/*:no/text()
        )[1]"/>
        
        
    </xsl:function>
    
</xsl:stylesheet>