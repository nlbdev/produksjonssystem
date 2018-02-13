<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.daisy.org/z3986/2005/dtbook/"
                xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes" doctype-public="-//NISO//DTD dtbook 2005-3//EN" doctype-system="http://www.daisy.org/z3986/2005/dtbook-2005-3.dtd"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="meta[@name=('dtb:uid','dc:Identifier')]">
        <xsl:variable name="identifier" select="(../meta[@name='nlbprod:identifier.daisy202'], ../meta[@name='nlbprod:identifier.daisy202.student'], ../meta[starts-with(@name,'nlbprod:identifier.daisy202')])[1]/@content" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="$identifier">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                    <xsl:attribute name="content" select="$identifier"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message select="concat('Finner ikke nlbprod:identifier.daisy202; ',@name,' forblir uendret (',@content,').')"/>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="doctitle">
        <xsl:variable name="title" select="/*/head/meta[lower-case(@name)='dc:title']/@content" as="xs:string?"/>
        <xsl:variable name="subTitle" select="/*/head/meta[lower-case(@name)='dc:title.subtitle']/@content" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="$title">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
                    <xsl:value-of select="$title"/>
                    <xsl:if test="$subTitle">
                        <xsl:text>: </xsl:text>
                        <xsl:value-of select="$subTitle"/>
                    </xsl:if>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message select="concat('Finner ikke nlbprod:identifier.daisy202; ',@name,' forblir uendret (',@content,').')"/>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:variable name="authors" select="/*/head/meta[lower-case(@name)='dc:creator']/@content" as="xs:string*"/>
        <xsl:variable name="authors" select="if (count($authors)) then $authors else /*/head/meta[lower-case(@name)='dc:contributor.editor']/@content" as="xs:string*"/>
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
    
    <xsl:template match="@xml:lang[. = /*/tokenize(lower-case(string(@xml:lang)),'-')[last()]]"/>
    
</xsl:stylesheet>