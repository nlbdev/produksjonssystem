<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output method="xhtml" indent="no" include-content-type="no"/>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h1">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx1 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h2">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx2 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h3">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx3 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h4">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx4 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h5">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx5 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h6">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx6 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="create-pagebreak">
        <xsl:variable name="page-number" select="if (@title) then @title else text()"/>
        <xsl:variable name="max-page-number" select="(//div | //span)[f:types(.) = 'pagebreak'][last()]/(if (@title) then @title else text())"/>
        
        <div epub:type="pagebreak">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="title" select="$page-number"/>
            <xsl:value-of select="concat('--- ', $page-number, ' til ', $max-page-number)"/>
        </div>
    </xsl:template>
    
    <xsl:template match="div[f:types(.) = 'pagebreak']">
        <xsl:call-template name="create-pagebreak"/>
    </xsl:template>
    
    <xsl:template match="span[f:types(.) = 'pagebreak']">
        <xsl:if test="not(exists(ancestor::h1 | ancestor::h2 | ancestor::h3 | ancestor::h4 | ancestor::h5 | ancestor::h6 | ancestor::p))">
            <xsl:call-template name="create-pagebreak"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6 | p" priority="10">
        <xsl:for-each select="descendant::span[f:types(.) = 'pagebreak']">
            <xsl:call-template name="create-pagebreak"/>
        </xsl:for-each>
        
        <xsl:next-match/>
    </xsl:template>
    
    <xsl:template match="img">
        <xsl:if test="string-length(@alt) gt 0">
            <p><xsl:value-of select="@alt"/></p>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="section[f:types(.) = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="node() except (h1, h2, h3, h4, h5, h6)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="ol[parent::section/f:types(.) = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            
            <li>
                <a href="#statped_merknad">xxx1 Merknad</a>
            </li>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="li[ancestor::section/f:types(.) = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:value-of select="concat('xxx', count(ancestor-or-self::li), ' ')"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="body">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            
            <xsl:variable name="title" select="/*/head/title/text()"/>
            <xsl:variable name="language" select="/*/head/meta[@name='dc:language']/@content"/>
            <xsl:variable name="authors" select="for $author in (/*/head/meta[@name='dc:creator']/@content) return replace($author, '^(.*), *(.*)$', '$2 $1')"/>
            <xsl:variable name="publisher-original" select="/*/head/meta[@name='dc:publisher.original']/@content"/>
            <xsl:variable name="publisher" select="/*/head/meta[@name='dc:publisher']/@content"/>
            <xsl:variable name="publisher-location" select="/*/head/meta[@name='dc:publisher.location']/@content"/>
            <xsl:variable name="issued" select="/*/head/meta[@name='dc:date.issued']/@content"/>
            <xsl:variable name="issued-original" select="/*/head/meta[@name='dc:issued.original']/@content"/>
            <xsl:variable name="edition-original" select="/*/head/meta[@name='schema:bookEdition.original']/@content"/>
            <xsl:variable name="pagebreaks" select="(//div | //span)[f:types(.) = 'pagebreak']"/>
            <xsl:variable name="first-page" select="if ($pagebreaks[1]/@title) then $pagebreaks[1]/@title else $pagebreaks[1]/text()"/>
            <xsl:variable name="last-page" select="if ($pagebreaks[last()]/@title) then $pagebreaks[last()]/@title else $pagebreaks[last()]/text()"/>
            <xsl:variable name="isbn" select="/*/head/meta[@name='schema:isbn']/@content"/>
            
            <p>
                <xsl:value-of select="$title"/>
                <xsl:if test="$language">
                    <xsl:value-of select="if ($language) then concat(' - ', $language) else ''"/>
                </xsl:if>
                <br/>
                
                <xsl:value-of select="if ($first-page) then concat('(s. ', $first-page, '-', $last-page, ')') else ''"/>
                <xsl:choose>
                    <xsl:when test="count($authors) gt 1">
                        <xsl:text> - </xsl:text>
                        <xsl:value-of select="string-join($authors[position() lt last()], ', ')"/>
                        <xsl:text> og </xsl:text>
                        <xsl:value-of select="$authors[last()]"/>
                    </xsl:when>
                    <xsl:when test="$authors">
                        <xsl:text> - </xsl:text>
                        <xsl:value-of select="$authors"/>
                    </xsl:when>
                </xsl:choose>
                <br/>
                
                <xsl:value-of select="$publisher-original"/>
                <xsl:value-of select="if ($issued-original) then concat(' ', $issued-original) else ''"/>
                <xsl:value-of select="if ($edition-original) then concat(' - ', $edition-original, if (matches($edition-original, '^\d+\.?')) then '.utg.' else '') else ''"/>
                <xsl:value-of select="if ($isbn) then concat(' - ISBN: ', $isbn) else ''"/>
            </p>
            
            <p>Denne boka er tilrettelagt for synshemmede. Ifølge lov om opphavsrett kan den ikke brukes av andre.
               Kopiering er kun tillatt til eget bruk. Brudd på disse avtalevilkårene, som ulovlig kopiering eller
               medvirkning til ulovlig kopiering, kan medføre ansvar etter åndsverkloven.<br/>
               
               <xsl:value-of select="$publisher-location"/>
               <xsl:value-of select="if ($issued) then concat(' ', $issued) else ''"/>
               <xsl:value-of select="if ($publisher) then concat(', ', $publisher) else ''"/>
               <xsl:value-of select="'.'"/>
            </p>
            
            <section>
                <h1>xxx1 Merknad</h1>
                <p>TODO</p>
            </section>
            
            <xsl:apply-templates select="section[f:types(.) = 'toc']"/>
            <xsl:apply-templates select="* except section[f:types(.) = 'toc']"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section[f:types(.) = 'titlepage']"/>
    <xsl:template match="section[f:types(.) = 'colophon']"/>
    
    <xsl:function name="f:types">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type,'\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:classes">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type,'\s+')"/>
    </xsl:function>
    
</xsl:stylesheet>
