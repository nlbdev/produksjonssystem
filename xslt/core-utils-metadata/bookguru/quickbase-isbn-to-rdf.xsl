<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:nlbprod="http://www.nlb.no/production"
                xmlns:nlb="http://www.nlb.no/"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:schema="http://schema.org/"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes" include-content-type="no"/>
    
    <xsl:param name="output-rdfa" select="false()"/>
    <xsl:param name="include-source-reference" select="false()"/>

    <xsl:template match="/qdbapi">
        <xsl:variable name="rid" select="/qdbapi/table/records/record/@rid" as="xs:string?"/>
        <xsl:variable name="metadata" as="node()*">
            <xsl:for-each select="/qdbapi/table/records/record/f">
                <xsl:sort select="@id"/>
                <xsl:variable name="meta" as="node()*">
                    <xsl:apply-templates select="."/>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$meta[self::html:dd]">
                        <xsl:copy-of select="$meta"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="label" select="/qdbapi/table/fields/field[@id=current()/@id]/label" as="xs:string?"/>
                        <xsl:variable name="book" select="(../f[@id='7'])[1]" as="xs:string?"/>
                        <xsl:variable name="metadata-source" select="concat('Quickbase ISBN@', $book, ' ', $label)"/>
                        <xsl:message select="concat('Ingen regel for QuickBase-felt i ISBN-tabell: ', @id, '(', $metadata-source, ')')"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="identifier" select="($metadata[self::html:dd[@property = 'nlbprod:isbn.identifier' and normalize-space(.)]])[1]/normalize-space(.)"/>
        <xsl:variable name="resource" select="if ($identifier) then concat('urn:nbn:no-nb_nlb_', $identifier) else concat('isbn_',($rid,replace(string(current-time()),'[^\d]',''))[1],'_book_', generate-id())"/>
        
        <xsl:choose>
            <xsl:when test="$output-rdfa">
                <html>
                    <head>
                        <title><xsl:value-of select="$metadata[self::html:dd[@property='nlbprod:isbn.title']]"/></title>
                        <style>
                        <xsl:text><![CDATA[
dl {
   margin-top: 0;
   margin-bottom: 1rem;
}

dt {
    font-weight: 700;
}

dd {
    margin-bottom: .5rem;
    margin-left: 0;
    text-indent: 2rem;
}

body {
    font-family: -apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;
    font-size: 1rem;
    font-weight: 400;
    line-height: 1.5;
    color: #292b2c;
    margin: 2rem;
}

section dl {
    margin-left: 2rem;
}

]]></xsl:text>
                        </style>
                    </head>
                    <body vocab="http://schema.org/" typeof="Book">
                        <xsl:attribute name="{if (matches($resource,'^(http|urn)')) then 'about' else 'id'}" select="$resource"/>
                        <h1><xsl:value-of select="$metadata[self::html:dd[@property='nlbprod:isbn.title']]"/></h1>
                        
                        <xsl:call-template name="list-metadata-rdfa">
                            <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                        </xsl:call-template>
                    </body>
                </html>
            </xsl:when>
            <xsl:otherwise>
                <rdf:RDF>
                    <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
                    <xsl:namespace name="schema" select="'http://schema.org/'"/>
                    <xsl:namespace name="nlbprod" select="'http://www.nlb.no/production'"/>
                    <rdf:Description>
                        <xsl:attribute name="rdf:{if (matches($resource,'^(http|urn)')) then 'about' else 'ID'}" select="$resource"/>
                        <rdf:type rdf:resource="http://schema.org/Book"/>
                        <xsl:call-template name="list-metadata-rdfxml">
                            <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                        </xsl:call-template>
                    </rdf:Description>
                </rdf:RDF>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="list-metadata-rdfa">
        <xsl:param name="metadata" as="element()*"/>
        <dl>
            <xsl:for-each-group select="$metadata" group-starting-with="html:dt">
                <xsl:if test="current-group()[self::html:dd[normalize-space(.)]]">
                    <xsl:variable name="baseType" select="(current-group()[self::html:dt]/@_base_type)[1]" as="xs:string"/>
                    <xsl:variable name="fieldType" select="(current-group()[self::html:dt]/@_field_type)[1]" as="xs:string"/>
                    <xsl:variable name="property" select="(current-group()[self::html:dd]/@property)[1]" as="xs:string"/>
                    <xsl:for-each select="current-group()[self::html:dt]">
                        <xsl:copy>
                            <xsl:copy-of select="@* except (@_type-id | @_field_type | @_base_type)"/>
                            <xsl:attribute name="title" select="$property"/>
                            <xsl:copy-of select="node()"/>
                        </xsl:copy>
                    </xsl:for-each>
                    <xsl:for-each select="current-group()[self::html:dd]">
                        <xsl:copy>
                            <xsl:copy-of select="@* except (@_type-id | @_field_type | @_base_type)"/>
                            <xsl:value-of select="f:quickbase-value(text()[1], $fieldType, $baseType)"/>
                        </xsl:copy>
                    </xsl:for-each>
                </xsl:if>
            </xsl:for-each-group>
        </dl>
    </xsl:template>
    
    <xsl:template name="list-metadata-rdfxml">
        <xsl:param name="metadata" as="element()*"/>
        <xsl:for-each-group select="$metadata" group-starting-with="html:dt">
            <xsl:if test="current-group()[self::html:dd[normalize-space(.)]]">
                <xsl:variable name="baseType" select="(current-group()[self::html:dt]/@_base_type)[1]" as="xs:string"/>
                <xsl:variable name="fieldType" select="(current-group()[self::html:dt]/@_field_type)[1]" as="xs:string"/>
                <xsl:variable name="property" select="(current-group()[self::html:dd]/@property)[1]" as="xs:string"/>
                <xsl:variable name="metadata-source" select="current-group()[self::html:dt]/@nlb:metadata-source" as="attribute()?"/>
                <xsl:for-each select="current-group()[self::html:dd]">
                    <xsl:element name="{@property}">
                        <xsl:copy-of select="$metadata-source"/>
                        <xsl:value-of select="f:quickbase-value(text()[1], $fieldType, $baseType)"/>
                    </xsl:element>
                </xsl:for-each>
            </xsl:if>
        </xsl:for-each-group>
    </xsl:template>
    
    <xsl:function name="f:quickbase-value" as="xs:string">
        <xsl:param name="value" as="xs:string"/>
        <xsl:param name="fieldType" as="xs:string"/>
        <xsl:param name="baseType" as="xs:string"/>
        <xsl:value-of select="string(if ($baseType = 'bool') then boolean(number($value))
                                else if ($fieldType = 'duration') then f:duration(number($value) div 1000)
                                else if ($fieldType = 'timestamp') then f:timestamp(xs:integer(number($value) div 1000))
                                else if ($fieldType = 'date') then f:date(xs:integer(number($value) div 1000))
                                else $value)"/>
    </xsl:function>
    
    <xsl:function name="f:duration" as="xs:string">
        <xsl:param name="seconds" as="xs:double"/>
        <xsl:variable name="s" select="$seconds mod 60"/>
        <xsl:variable name="m" select="xs:integer(($seconds - $s) div 60 mod 60)"/>
        <xsl:variable name="h" select="xs:integer(($seconds - $s - $m * 60) div 3600)"/>
        <xsl:value-of select="concat($h,':',format-number($m,'00'),':',format-number($s,'00.###'))"/>
    </xsl:function>
    
    <xsl:function name="f:timestamp" as="xs:string">
        <xsl:param name="epoch" as="xs:integer"/>
        <xsl:value-of select="string(xs:dateTime('1970-01-01T00:00:00') + xs:dayTimeDuration(concat('PT', $epoch, 'S')))"/>
    </xsl:function>
    
    <xsl:function name="f:date" as="xs:string">
        <xsl:param name="epoch" as="xs:integer"/>
        <xsl:value-of select="string(xs:date('1970-01-01') + xs:dayTimeDuration(concat('PT', $epoch, 'S')))"/>
    </xsl:function>
    
    <xsl:template match="f" priority="2">
        <xsl:variable name="id" select="@id"/>
        <dt _field_type="{/qdbapi/table/fields/field[@id=$id]/@field_type}" _base_type="{/qdbapi/table/fields/field[@id=$id]/@base_type}">
            
            <xsl:if test="$include-source-reference">
                <xsl:variable name="label" select="/qdbapi/table/fields/field[@id=current()/@id]/label" as="xs:string?"/>
                <xsl:variable name="book" select="(../f[@id='7'])[1]" as="xs:string?"/>
                <xsl:attribute name="nlb:metadata-source" select="concat('Quickbase ISBN@', $book, ' ', $label)"/>
            </xsl:if>
            
            <xsl:value-of select="/qdbapi/table/fields/field[@id=$id]/label"/>
        </dt>
        <xsl:next-match/>
    </xsl:template>
    
    <xsl:template match="f[@id='1']">
        <!-- timestamp / int64 (Date Created) -->
        <dd property="nlbprod:isbn.created">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='2']">
        <!-- timestamp / int64 (Date Modified) -->
        <dd property="nlbprod:isbn.modified">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='3']">
        <!-- recordid / int32 (Record ID#) -->
        <dd property="nlbprod:isbn.recordid">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='4']">
        <!-- userid / text (Record Owner) -->
        <dd property="nlbprod:isbn.owner">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='5']">
        <!-- userid / text (Last Modified By) -->
        <dd property="nlbprod:isbn.modifier">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='6']">
        <!-- text -->
        <dd property="nlbprod:isbn">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='7']">
        <!-- text -->
        <dd property="nlbprod:isbn.identifier">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='8']">
        <!-- text -->
        <dd property="nlbprod:isbn.title">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='9']">
        <!-- text -->
        <dd property="nlbprod:isbn.creator">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='10']">
        <!-- text -->
        <dd property="nlbprod:isbn.user">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
</xsl:stylesheet>
