<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="#"
                xmlns="http://www.daisy.org/z3986/2005/dtbook/"
                xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes" doctype-public="-//NISO//DTD dtbook 2005-3//EN"/>
    
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
    
    <xsl:template match="doctitle">
        <xsl:next-match/>
        
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
    </xsl:template>
    
    <xsl:template match="docauthor"/>
    
    <xsl:template match="meta[lower-case(@name)='dc:language']">
        <meta name="dc:Language" content="{f:lang(@content)}"/>
    </xsl:template>
    
    <xsl:template match="h1[@class='title fulltitle']"/>   
    
    <xsl:template match="p[@class='docauthor author']"/>
    
    <!-- remove links from the toc -->
    <xsl:template match="a[exists(ancestor::list) and exists(ancestor::*[tokenize(@class,'\s+') = 'toc'])]">
        <xsl:apply-templates select="node()"/>
    </xsl:template>
    
    <xsl:template match="@xml:lang[not(parent::dtbook) and . = /*/tokenize(lower-case(string(@xml:lang)),'-')[last()]]" priority="2"/> 
    
    <xsl:template match="@xml:lang">
        <xsl:attribute name="xml:lang" select="f:lang(.)"/>
    </xsl:template>
    
    <xsl:function name="f:lang" as="xs:string">
        <xsl:param name="lang" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="tokenize($lang,'-')[1] = ('nb','nn')">
                <xsl:value-of select="'no'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="tokenize($lang,'-')[1]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>