<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="#"
                xmlns="http://www.daisy.org/z3986/2005/dtbook/"
                xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" doctype-public="-//NISO//DTD dtbook 2005-3//EN"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="head">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
            <xsl:if test="not(meta[@name='dc:Date'])">
                <meta name="dc:Date" content="{tokenize(string(current-date()),'\+')[1]}"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="meta[starts-with(@name,'nlb')]">
        <xsl:variable name="name" as="xs:string*">
            <xsl:value-of select="tokenize(@name,'\.')[1]"/>
            <xsl:for-each select="tokenize(@name,'\.')[position() gt 1]">
                <xsl:value-of select="upper-case(substring(.,1,1))"/>
                <xsl:value-of select="substring(.,2)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="name" select="string-join($name,'')"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="meta[starts-with(lower-case(@name), 'dc:') and not(matches(lower-case(@name), '^dc:(title|subject|description|type|source|relation|coverage|creator|publisher|contributor|rights|date|format|identifier|language)$'))]">
        <xsl:comment>
            <xsl:text> not allowed in DTBook: </xsl:text>
            <xsl:text>&lt;meta</xsl:text>
            <xsl:for-each select="@*">
                <xsl:value-of select="concat(' ', name(), '=&quot;', ., '&quot;')"/>
            </xsl:for-each>
            <xsl:text>/&gt; </xsl:text>
        </xsl:comment>
    </xsl:template>
    
    <xsl:template match="doctitle">
        <xsl:next-match/>
        
        <xsl:variable name="responsibilityStatement" select="/*/head/meta[@name = 'nlbbib:responsibilityStatement']/@content" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="$responsibilityStatement">
                <docauthor>
                    <xsl:value-of select="$responsibilityStatement"/>
                </docauthor>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="authors" select="/*/head/meta[lower-case(@name)='dc:creator']/@content" as="xs:string*"/>
                <xsl:variable name="authors" select="if (count($authors)) then $authors else /*/head/meta[lower-case(@name)='dc:contributor.editor']/concat(string-join(reverse(tokenize(@content,' *, *')),' '),' (red.)')" as="xs:string*"/>
                <xsl:variable name="authors" select="if (count($authors)) then $authors else /*/head/meta[lower-case(@name)='dc:publisher.original']/@content" as="xs:string*"/>
                <xsl:variable name="authors" select="if (count($authors)) then $authors else /*/head/meta[lower-case(@name)='dc:publisher']/@content" as="xs:string*"/>
                <xsl:for-each select="$authors">
                    <docauthor>
                        <xsl:value-of select="string-join(reverse(tokenize(.,' *, *')),' ')"/>
                    </docauthor>
                </xsl:for-each>
                <xsl:if test="count($authors) = 0">
                    <xsl:message select="'Fant ingen forfattere (dc:creator) eller redaktører (dc:contributor.editor).'"/>
                    <xsl:copy-of select="following-sibling::docauthor" exclude-result-prefixes="#all"/>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="docauthor"/>
    
    <xsl:template match="meta[lower-case(@name)='dc:language']">
        <meta name="dc:Language" content="{f:lang(@content)}"/>
    </xsl:template>
    
    <xsl:template match="h1[tokenize(@class, '\s+') = 'fulltitle']"/>
    
    <xsl:template match="p[tokenize(@class,'\s+') = 'docauthor']"/>
    <!--and exists(../* except (../p[tokenize(@class, '\s+') = 'docauthor'] | ../*[local-name() = ('h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hd', 'pagenum')]))]-->
    
    <xsl:template match="level1">
        <xsl:variable name="result" as="element()">
            <xsl:next-match/>
        </xsl:variable>
        
        <xsl:for-each select="$result">  <!-- set resulting level1 as context -->
            <xsl:choose>
                <xsl:when test="exists(h1/following-sibling::*)">
                    <!-- perfectly valid level1, just copy the result we already have -->
                    <xsl:copy-of select="."/>
                </xsl:when>
                
                <xsl:when test="exists(h1/preceding-sibling::*)">
                    <!-- h1 with preceding element(s) but no following elements -->
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:copy-of select="h1/preceding-sibling::*[1]/preceding-sibling::node()"/> <!-- for instance when there's more than one pagenum, then let's only move one of them -->
                        <xsl:copy-of select="h1"/>
                        <xsl:copy-of select="h1/preceding-sibling::node() intersect h1/preceding-sibling::*[1]/following-sibling::node()"/>  <!-- nodes (i.e. whitespace) between the h1 and its preceding element-->
                        <xsl:copy-of select="h1/preceding-sibling::*[1]"/>
                        <xsl:copy-of select="h1/following-sibling::node()"/>
                    </xsl:copy>
                </xsl:when>
                
                <xsl:when test="exists(h1)">
                    <!-- only a h1 in the level1. Let's make it into a p. -->
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:copy-of select="h1/preceding-sibling::node()"/>
                        <p>
                            <xsl:copy-of select="h1/@*"/>
                            <xsl:copy-of select="h1/node()"/>
                        </p>
                        <xsl:copy-of select="h1/following-sibling::node()"/>
                    </xsl:copy>
                </xsl:when>
                
                <xsl:when test="exists(*)">
                    <!-- there are elements, there's just no h1. Should be valid, let's copy the result we already have -->
                    <xsl:copy-of select="."/>
                </xsl:when>
                
                <xsl:otherwise>
                    <!-- no remaining elements in the level1. Let's delete it -->
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <!-- remove links from the toc -->
    <xsl:template match="a[exists(ancestor::list) and exists(ancestor::*[tokenize(@class,'\s+') = 'toc'])]">
        <xsl:apply-templates select="node()"/>
    </xsl:template>
    
    <xsl:template match="@xml:lang[not(parent::dtbook) and . = /*/tokenize(lower-case(string(@xml:lang)),'-')[last()]]" priority="2"/> 
    
    <xsl:template match="@xml:lang">
        <xsl:attribute name="xml:lang" select="f:lang(.)"/>
    </xsl:template>
    
    <!-- remove alt attribute content from the TTS-version -->
    <xsl:template match="@alt">
        <xsl:attribute name="alt" select="''"/>
    </xsl:template>
    
    <xsl:function name="f:lang" as="xs:string">
        <xsl:param name="lang" as="xs:string"/>
        <xsl:value-of select="tokenize($lang,'-')[1]"/>
    </xsl:function>
    
</xsl:stylesheet>