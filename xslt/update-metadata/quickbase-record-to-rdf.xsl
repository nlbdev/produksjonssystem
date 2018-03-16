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
    
    <xsl:output indent="yes" method="xhtml"/>
    
    <xsl:param name="rdf-xml-path" as="xs:string"/>
    <xsl:param name="include-source-reference" select="false()"/>

    <xsl:template match="/qdbapi">
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
                        <xsl:message select="concat('Ingen regel for QuickBase-felt i Record-tabell: ', @id)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="resource-creativeWork" select="f:resource($metadata, 'creativeWork')"/>
        
        <html>
            <head>
                <title><xsl:value-of select="$metadata[self::html:dd[@property='nlbprod:title']]"/></title>
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
            <body vocab="http://schema.org/" typeof="CreativeWork">
                <xsl:attribute name="{if (matches($resource-creativeWork,'^(http|urn)')) then 'about' else 'id'}" select="$resource-creativeWork"/>
                <h1><xsl:value-of select="$metadata[self::html:dd[@property='nlbprod:title']]"/></h1>
                
                <xsl:call-template name="list-metadata-rdfa">
                    <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                    <xsl:with-param name="type-id" select="'creativeWork'"/>
                </xsl:call-template>
                
                <xsl:for-each select="distinct-values($metadata/@_type-id[not(.='creativeWork')])">
                    <section vocab="http://schema.org/" typeof="Book">
                        <xsl:variable name="resource" select="f:resource($metadata, .)"/>
                        <xsl:attribute name="{if (matches($resource,'^(http|urn)')) then 'about' else 'id'}" select="$resource"/>
                        <link property="exampleOfWork" href="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                        <h2><xsl:value-of select="if (. = '#epub') then 'EPUB' else if (. = '#audio') then 'Lydbok' else if (. = '#braille') then 'Punktskrift' else if (. = '#ebook') then 'E-tekst' else if (. = '#external') then 'Ekstern' else ."/></h2>
                        <xsl:call-template name="list-metadata-rdfa">
                            <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                            <xsl:with-param name="type-id" select="."/>
                        </xsl:call-template>
                    </section>
                </xsl:for-each>
            </body>
        </html>
        
        <xsl:if test="$rdf-xml-path">
            <xsl:result-document href="{$rdf-xml-path}" indent="yes">
                <rdf:RDF>
                    <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
                    <xsl:namespace name="schema" select="'http://schema.org/'"/>
                    <xsl:namespace name="nlbprod" select="'http://www.nlb.no/production'"/>
                    <rdf:Description>
                        <xsl:attribute name="rdf:{if (matches($resource-creativeWork,'^(http|urn)')) then 'about' else 'ID'}" select="$resource-creativeWork"/>
                        <rdf:type rdf:resource="http://schema.org/CreativeWork"/>
                        <xsl:call-template name="list-metadata-rdfxml">
                            <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                            <xsl:with-param name="type-id" select="'creativeWork'"/>
                        </xsl:call-template>
                    </rdf:Description>
                    <xsl:for-each select="distinct-values($metadata/@_type-id[not(.='creativeWork')])">
                        <rdf:Description>
                            <xsl:variable name="resource" select="f:resource($metadata, .)"/>
                            <xsl:attribute name="rdf:{if (matches($resource,'^(http|urn)')) then 'about' else 'ID'}" select="$resource"/>
                            <rdf:type rdf:resource="http://schema.org/Book"/>
                            <schema:exampleOfWork rdf:resource="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                            <xsl:call-template name="list-metadata-rdfxml">
                                <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                                <xsl:with-param name="type-id" select="."/>
                            </xsl:call-template>
                        </rdf:Description>
                    </xsl:for-each>
                </rdf:RDF>
            </xsl:result-document>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="list-metadata-rdfa">
        <xsl:param name="metadata" as="element()*"/>
        <xsl:param name="type-id" as="xs:string"/>
        <dl>
            <xsl:for-each-group select="$metadata" group-starting-with="html:dt">
                <xsl:if test="current-group()[self::html:dd[@_type-id=$type-id and normalize-space(.)]]">
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
        <xsl:param name="type-id" as="xs:string"/>
        <xsl:for-each-group select="$metadata" group-starting-with="html:dt">
            <xsl:if test="current-group()[self::html:dd[@_type-id=$type-id and normalize-space(.)]]">
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
    
    <xsl:function name="f:resource">
        <xsl:param name="metadata" as="element()*" required="yes"/>
        <xsl:param name="type-id" as="xs:string" required="yes"/>
        <xsl:variable name="identifier" select="($metadata[self::html:dd[@_type-id=$type-id and starts-with(@property,'nlbprod:identifier') and normalize-space(.)]])[1]/normalize-space(.)"/>
        <xsl:choose>
            <xsl:when test="$identifier">
                <xsl:value-of select="concat('http://websok.nlb.no/cgi-bin/websok?tnr=', $identifier)"/>
            </xsl:when>
            <xsl:when test="$type-id = 'creativeWork' and count($metadata[self::html:dd[@property=('nlbprod:originalISBN', 'nlbprod:dcSourceUrnIsbn') and normalize-space(.)]])">
                <xsl:variable name="isn" select="($metadata[self::html:dd[@property=('nlbprod:originalISBN', 'nlbprod:dcSourceUrnIsbn') and normalize-space(.)]])[1]/replace(normalize-space(.),'[^\d]','')"/>
                <xsl:variable name="prefix" select="concat('urn:', if (string-length($isn) = 8) then 'issn' else 'isbn', ':', $isn)"/>
                <xsl:value-of select="concat($prefix, $isn)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat('record_',replace(string(current-time()),'[^\d]',''), $type-id, '_', ($metadata[1]/generate-id(), '')[1])"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
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
                <xsl:variable name="book" select="(../f[@id='13'])[1]" as="xs:string?"/>
                <xsl:attribute name="nlb:metadata-source" select="concat('Quickbase Record@', $book, ' ', $label)"/>
            </xsl:if>
            
            <xsl:value-of select="/qdbapi/table/fields/field[@id=$id]/label"/>
        </dt>
        <xsl:next-match/>
    </xsl:template>
    
    <xsl:template match="f[@id='1']">
        <!-- Integer -->
       <dd property="nlbprod:dateCreated" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='2']">
        <!-- Integer -->
        <dd property="nlbprod:dateModified" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='3']">
        <!-- Integer -->
        <dd property="nlbprod:recordId" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='4']">
        <!-- String -->
        <dd property="nlbprod:recordOwner" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='5']">
        <!-- String -->
        <dd property="nlbprod:lastModifiedBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='6']">
        <!-- Integer -->
        <dd property="nlbprod:registrationDate" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='7']">
        <!-- String -->
        <dd property="nlbprod:createdBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='8']">
        <!-- String -->
        <dd property="nlbprod:title" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='9']">
        <!-- String -->
        <dd property="nlbprod:author" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='10']">
        <!-- String -->
        <dd property="nlbprod:publisher" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='11']">
        <!-- String -->
        <dd property="schema:isbn" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='12']">
        <!-- String -->
        <dd property="nlbprod:productionTurnaroundTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='13']">
        <!-- Integer -->
        <dd property="nlbprod:identifier.epub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='14']">
        <!-- Boolean -->
        <dd property="nlbprod:epubCatalogued" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='15']">
        <!-- Boolean -->
        <dd property="nlbprod:sourceFileReceived" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='16']">
        <!-- String -->
        <dd property="nlbprod:producer" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='17']">
        <!-- Boolean -->
        <dd property="nlbprod:productionApproved" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='18']">
        <!-- Integer -->
        <dd property="nlbprod:numberOfPages" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='19']">
        <!-- Integer -->
        <dd property="nlbprod:numberOfImages" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='20']">
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='21']">
        <!-- String -->
        <dd property="nlbprod:nlbIsbnDaisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='22']">
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narrated" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='23']">
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202tts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='24']">
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202.student" _type-id="audio" id="identifier-daisy202student">
            <xsl:value-of select="."/>
        </dd>
        <!--<dd property="dcterms:audience" _type-id="audio" refines="#identifier-daisy202student">Student</dd>-->
    </xsl:template>
    
    <xsl:template match="f[@id='25']">
        <!-- String -->
        <dd property="nlbprod:nlbIsbnDaisy202student" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='26']">
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narratedStudent" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='27']">
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202ttsStudent" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='28']">
        <!-- Integer -->
        <dd property="nlbprod:identifier.braille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='29']">
        <!-- String -->
        <dd property="nlbprod:nlbIsbnBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='30']">
        <!-- Boolean -->
        <dd property="nlbprod:formatBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='31']">
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202.fulltext" _type-id="audio" id="identifier-daisy202narratedfulltext">
            <xsl:value-of select="."/>
        </dd>
        <!--<dd property="dc:type" _type-id="audio" refines="#identifier-daisy202narratedfulltext">Narrated Fulltext</dd>-->
    </xsl:template>
    
    <xsl:template match="f[@id='32']">
        <!-- Integer -->
        <dd property="nlbprod:identifier.ebook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='33']">
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narratedFulltext" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='36']">
        <!-- String -->
        <dd property="nlbprod:nlbIsbnEbook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='37']">
        <!-- Boolean -->
        <dd property="nlbprod:formatEbook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='38']">
        <!-- Integer -->
        <dd property="nlbprod:identifier.external" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='40']">
        <!-- Boolean -->
        <dd property="nlbprod:preparedForNarration" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='41']">
        <!-- Boolean -->
        <dd property="nlbprod:daisy202productionComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='42']">
        <!-- Boolean -->
        <dd property="nlbprod:daisy202ttsProductionComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='43']">
        <!-- Boolean -->
        <dd property="nlbprod:brailleProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='44']">
        <!-- Boolean -->
        <dd property="nlbprod:ebookProductionComplete" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='46']">
        <!-- Boolean -->
        <dd property="nlbprod:handedOverToNarrator" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='47']">
        <!-- Integer -->
        <dd property="nlbprod:timeForLastChange" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='48']">
        <!-- String -->
        <dd property="nlbprod:lastChangedBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='49']">
        <!-- Integer -->
        <dd property="nlbprod:productionsId" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='51']">
        <!-- String -->
        <dd property="nlbprod:commentCatalogization" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='55']">
        <!-- Boolean -->
        <dd property="nlbprod:sourceFileOrdered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='56']">
        <!-- Integer -->
        <dd property="nlbprod:catalogizationDateEpub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='58']">
        <!-- String -->
        <dd property="nlbprod:wipsIsbn" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='60']">
        <!-- Boolean -->
        <dd property="nlbprod:forManualPreparationInNLB" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='61']">
        <!-- Integer -->
        <dd property="nlbprod:productionApprovedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='62']">
        <!-- Integer -->
        <dd property="nlbprod:orderDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='63']">
        <!-- String -->
        <dd property="nlbprod:narrator" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='64']">
        <!-- Integer -->
        <dd property="nlbprod:narrationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='65']">
        <!-- Integer -->
        <dd property="nlbprod:handedOverToNarratorDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='66']">
        <!-- String -->
        <dd property="nlbprod:student" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='67']">
        <!-- String -->
        <dd property="nlbprod:genre" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='68']">
        <!-- Boolean -->
        <dd property="nlbprod:narrationComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='69']">
        <!-- Integer -->
        <dd property="nlbprod:narrationCompletionDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='71']">
        <!-- Integer -->
        <dd property="nlbprod:agreedNarrationCompletionDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='73']">
        <!-- Integer -->
        <dd property="nlbprod:preparedDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='74']">
        <!-- String -->
        <dd property="nlbprod:producer2" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='77']">
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202wips" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='80']">
        <!-- String -->
        <dd property="nlbprod:addRecord" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='81']">
        <!-- Integer -->
        <dd property="nlbprod:sourceFileOrderedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='82']">
        <!-- Integer -->
        <dd property="nlbprod:sourceFileReceivedOrScannedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='83']">
        <!-- String -->
        <dd property="nlbprod:sourceFileFormat" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='84']">
        <!-- Boolean -->
        <dd property="nlbprod:epubDTBookOrdered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='85']">
        <!-- Integer -->
        <dd property="nlbprod:daisy202ProductionCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='86']">
        <!-- Integer -->
        <dd property="nlbprod:daisy202ttsProductionCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='87']">
        <!-- Integer -->
        <dd property="nlbprod:brailleProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='88']">
        <!-- Integer -->
        <dd property="nlbprod:ebookProductionCompleteDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='97']">
        <!-- Number -->
        <dd property="nlbprod:feeNarratedTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='98']">
        <!-- Number -->
        <dd property="nlbprod:feePreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='99']">
        <!-- Number -->
        <dd property="nlbprod:additionalFeeNightAndWeekend" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='103']">
        <!-- Number -->
        <dd property="nlbprod:narratedTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='116']">
        <!-- Integer -->
        <dd property="nlbprod:preparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='117']">
        <!-- Integer -->
        <dd property="nlbprod:additionalNightAndWeekend" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='119']">
        <!-- Number -->
        <dd property="nlbprod:preparationTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='120']">
        <!-- Number -->
        <dd property="nlbprod:nightAndWeekendInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='122']">
        <!-- Number -->
        <dd property="nlbprod:sumFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='131']">
        <!-- Integer -->
        <dd property="nlbprod:otherWorkForNLB" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='137']">
        <!-- Boolean -->
        <dd property="nlbprod:feeComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='138']">
        <!-- Integer -->
        <dd property="nlbprod:feeCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='139']">
        <!-- Number -->
        <dd property="nlbprod:otherWorkInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='141']">
        <!-- Number -->
        <dd property="nlbprod:advancePayment" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='142']">
        <!-- Number -->
        <dd property="nlbprod:totalSumFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='143']">
        <!-- Integer -->
        <dd property="nlbprod:advancePaymentDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='145']">
        <!-- Number -->
        <dd property="nlbprod:feeOtherWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='146']">
        <!-- Boolean -->
        <dd property="nlbprod:daisy202readyForLoan" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='147']">
        <!-- Integer -->
        <dd property="nlbprod:daisy202readyForLoanDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='148']">
        <!-- String -->
        <dd property="nlbprod:narrationComment" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='149']">
        <!-- Boolean -->
        <dd property="nlbprod:brailleReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='150']">
        <!-- Integer -->
        <dd property="nlbprod:brailleReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='151']">
        <!-- Boolean -->
        <dd property="nlbprod:ebookReadyForLoan" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='152']">
        <!-- Integer -->
        <dd property="nlbprod:EBOOKReadyForLoanDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='153']">
        <!-- String -->
        <dd property="nlbprod:orderFormExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='154']">
        <!-- Boolean -->
        <dd property="nlbprod:dtbookReturned" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='155']">
        <!-- Integer -->
        <dd property="nlbprod:dtbookReturnedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='156']">
        <!-- Integer -->
        <dd property="nlbprod:daisy202ExpectedCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='157']">
        <!-- Integer -->
        <dd property="nlbprod:daisy202studentExpectedCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='158']">
        <!-- Integer -->
        <dd property="nlbprod:brailleExpectedCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='159']">
        <!-- Integer -->
        <dd property="nlbprod:ebookProductionExpectedCompleteDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='160']">
        <!-- Integer -->
        <dd property="nlbprod:externalProductionExpectedCompleteDate" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='161']">
        <!-- Integer -->
        <dd property="nlbprod:dueDateForProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='163']">
        <!-- String -->
        <dd property="nlbprod:editingInstructions" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='164']">
        <!-- String -->
        <dd property="nlbprod:translator" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='165']">
        <!-- String -->
        <dd property="nlbprod:language" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='167']">
        <!-- String -->
        <dd property="nlbprod:deliveryControl" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='170']">
        <!-- String -->
        <dd property="nlbprod:category" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='171']">
        <!-- Boolean -->
        <dd property="nlbprod:formatNotes" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='175']">
        <!-- String -->
        <dd property="nlbprod:commentPostProduction" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='176']">
        <!-- Integer -->
        <dd property="nlbprod:playtimeDaisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='177']">
        <!-- Integer -->
        <dd property="nlbprod:playtimeDaisy202tts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='178']">
        <!-- Boolean -->
        <dd property="nlbprod:formatBrailleClub" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='180']">
        <!-- Boolean -->
        <dd property="nlbprod:notForFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='184']">
        <!-- Integer -->
        <dd property="nlbprod:extraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='185']">
        <!-- Number -->
        <dd property="nlbprod:extraPreparationTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='186']">
        <!-- Number -->
        <dd property="nlbprod:feeExtraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='262']">
        <!-- Boolean -->
        <dd property="nlbprod:generateFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='268']">
        <!-- Boolean -->
        <dd property="nlbprod:openLinespacing" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='269']">
        <!-- String -->
        <dd property="nlbprod:braillePages" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='270']">
        <!-- String -->
        <dd property="nlbprod:volumes" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='279']">
        <!-- Number -->
        <dd property="nlbprod:rateNarrationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='280']">
        <!-- Number -->
        <dd property="nlbprod:ratePreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='281']">
        <!-- Number -->
        <dd property="nlbprod:rateExtraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='282']">
        <!-- Number -->
        <dd property="nlbprod:rateAdditionalWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='285']">
        <!-- Number -->
        <dd property="nlbprod:rateOtherWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='286']">
        <!-- String -->
        <dd property="nlbprod:feeModel" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='304']">
        <!-- Boolean -->
        <dd property="nlbprod:generateReceipt" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='308']">
        <!-- Number -->
        <dd property="nlbprod:employeeNumber" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='309']">
        <!-- String -->
        <dd property="nlbprod:account" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='310']">
        <!-- Number -->
        <dd property="nlbprod:costLocation" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='311']">
        <!-- Number -->
        <dd property="nlbprod:overriding" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='312']">
        <!-- Number -->
        <dd property="nlbprod:paymentType" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='314']">
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionDaisy202" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='315']">
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionDaisy202tts" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='316']">
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionBraille" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='317']">
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionEbook" _type-id="ebook">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='318']">
        <!-- Boolean -->
        <dd property="nlbprod:singlePagePrint" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='319']">
        <!-- Boolean -->
        <dd property="nlbprod:brailleClubProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='320']">
        <!-- Integer -->
        <dd property="nlbprod:brailleClubProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='321']">
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionBrailleClub" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='323']">
        <!-- String -->
        <dd property="nlbprod:signaturePreparation" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='324']">
        <!-- String -->
        <dd property="nlbprod:signatureDaisy202readyForLoan" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='325']">
        <!-- String -->
        <dd property="nlbprod:signatureEbookReadyForLoan" _type-id="ebook">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='326']">
        <!-- String -->
        <dd property="nlbprod:signatureBrailleReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='327']">
        <!-- Boolean -->
        <dd property="nlbprod:brailleClubReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='328']">
        <!-- Integer -->
        <dd property="nlbprod:brailleClubReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='329']">
        <!-- String -->
        <dd property="nlbprod:signatureBrailleClubReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='330']">
        <!-- String -->
        <dd property="nlbprod:priceCategory" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='342']">
        <!-- String -->
        <dd property="nlbprod:emailPublisherContact" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='343']">
        <!-- String -->
        <dd property="nlbprod:emailStudent" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='344']">
        <!-- String -->
        <dd property="nlbprod:signatureDTBookOrdered" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='345']">
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202externalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='346']">
        <!-- Boolean -->
        <dd property="nlbprod:formatEbookExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='347']">
        <!-- Boolean -->
        <dd property="nlbprod:formatAudioCDWAVExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='348']">
        <!-- Boolean -->
        <dd property="nlbprod:formatAudioCDMP3ExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='349']">
        <!-- Boolean -->
        <dd property="nlbprod:formatOtherExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='350']">
        <!-- String -->
        <dd property="nlbprod:commentExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='351']">
        <!-- Boolean -->
        <dd property="nlbprod:externalProductionProductionComplete" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='352']">
        <!-- Integer -->
        <dd property="nlbprod:externalProductionProductionCompleteDate" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='353']">
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionExternalProduction" _type-id="external">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='354']">
        <!-- Integer -->
        <dd property="nlbprod:playtimeExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='357']">
        <!-- String -->
        <dd property="nlbprod:feeForMultipleNarrators" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='360']">
        <!-- String -->
        <dd property="nlbprod:signatureDeliveredToNarrator" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='362']">
        <!-- Boolean -->
        <dd property="nlbprod:duplicate" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='366']">
        <!-- Boolean -->
        <dd property="nlbprod:partialBrailleProduction" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='367']">
        <!-- Boolean -->
        <dd property="nlbprod:formatBraillePartialProduction" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='368']">
        <!-- Boolean -->
        <dd property="nlbprod:formatTactilePrint" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='370']">
        <!-- String -->
        <dd property="nlbprod:commentBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='371']">
        <!-- Boolean -->
        <dd property="nlbprod:tactilePrintReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='372']">
        <!-- Integer -->
        <dd property="nlbprod:tactilePrintReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='374']">
        <!-- Boolean -->
        <dd property="nlbprod:tactilePrintProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='375']">
        <!-- Integer -->
        <dd property="nlbprod:tactilePrintProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='377']">
        <!-- String -->
        <dd property="nlbprod:signatureTactilePrintProductionComplete" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='378']">
        <!-- String -->
        <dd property="nlbprod:signatureTactilePrintReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='379']">
        <!-- Integer -->
        <dd property="nlbprod:waitingBecauseOfTechnicalProblems" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='380']">
        <!-- Integer -->
        <dd property="nlbprod:inStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='381']">
        <!-- Number -->
        <dd property="nlbprod:rateWaitingTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='382']">
        <!-- Number -->
        <dd property="nlbprod:rateInStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='383']">
        <!-- Number -->
        <dd property="nlbprod:waitingBecauseOfTechnicalProblemsInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='384']">
        <!-- Number -->
        <dd property="nlbprod:inStudioWithProducerInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='385']">
        <!-- Number -->
        <dd property="nlbprod:compensationWaitingTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='386']">
        <!-- Number -->
        <dd property="nlbprod:compensationInStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='387']">
        <!-- String -->
        <dd property="nlbprod:sourceFile" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='388']">
        <!-- String -->
        <dd property="nlbprod:estimatedBookCategory" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='389']">
        <!-- String -->
        <dd property="nlbprod:bookCategory" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='390']">
        <!-- Integer -->
        <dd property="nlbprod:numberOfPages2" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='392']">
        <!-- String -->
        <dd property="nlbprod:uploadEpub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='393']">
        <!-- Boolean -->
        <dd property="nlbprod:productionDelivered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='395']">
        <!-- Integer -->
        <dd property="nlbprod:productionDeliveryDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='396']">
        <!-- String -->
        <dd property="nlbprod:agency" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='397']">
        <!-- Number -->
        <dd property="nlbprod:productionNumberUID" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='398']">
        <!-- Boolean -->
        <dd property="nlbprod:leaveAMessage" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='399']">
        <!-- String -->
        <dd property="nlbprod:productionQuestionsAndNotes" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='402']">
        <!-- String -->
        <dd property="nlbprod:commentOrder" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='403']">
        <!-- String -->
        <dd property="nlbprod:purchaseOrderId" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='405']">
        <!-- Boolean -->
        <dd property="nlbprod:asciimath" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='406']">
        <!-- String -->
        <dd property="nlbprod:sourceFileFormat2" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='407']">
        <!-- String -->
        <dd property="nlbprod:alternateSourceFileURL" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='408']">
        <!-- Boolean -->
        <dd property="nlbprod:exercisesAndAnswers" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='409']">
        <!-- Boolean -->
        <dd property="nlbprod:inlineTextStyling" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='410']">
        <!-- Boolean -->
        <dd property="nlbprod:extractionOfTextContentInImages" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='413']">
        <!-- Boolean -->
        <dd property="nlbprod:productionReturned" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='414']">
        <!-- Integer -->
        <dd property="nlbprod:productionReturnDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='415']">
        <!-- String -->
        <dd property="nlbprod:commentEpubOrder" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='416']">
        <!-- Boolean -->
        <dd property="nlbprod:productionDownloaded" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='417']">
        <!-- Integer -->
        <dd property="nlbprod:downloadedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='418']">
        <!-- String -->
        <dd property="nlbprod:signatureForDownload" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='419']">
        <!-- Integer -->
        <dd property="nlbprod:pages" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='420']">
        <!-- String -->
        <dd property="nlbprod:title2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='421']">
        <!-- String -->
        <dd property="nlbprod:author2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='422']">
        <!-- String -->
        <dd property="nlbprod:contributor" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='423']">
        <!-- String -->
        <dd property="nlbprod:language2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='426']">
        <!-- String -->
        <dd property="nlbprod:signatureApprovedProduction" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='427']">
        <!-- String -->
        <dd property="nlbprod:signatureReturnedProduction" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='428']">
        <!-- String -->
        <dd property="nlbprod:validationLogFile" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='429']">
        <!-- String -->
        <dd property="nlbprod:originalISSN" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='430']">
        <!-- String -->
        <dd property="nlbprod:volumeNumber" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='431']">
        <!-- String -->
        <dd property="nlbprod:dcSourceUrnIsbn" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='432']">
        <!-- Boolean -->
        <dd property="nlbprod:urgentProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='434']">
        <!-- Number -->
        <dd property="nlbprod:nightAndWeekendPercentageOfTotalTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='436']">
        <!-- String -->
        <dd property="nlbprod:signatureFee" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='437']">
        <!-- String -->
        <dd property="nlbprod:signatureRegistration" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='438']">
        <!-- Boolean -->
        <dd property="nlbprod:newRegistration" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='439']">
        <!-- String -->
        <dd property="nlbprod:narratorCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='440']">
        <!-- Number -->
        <dd property="nlbprod:employeeNumberCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='442']">
        <!-- Integer -->
        <dd property="nlbprod:agreedNarrationCompletionDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='443']">
        <!-- Boolean -->
        <dd property="nlbprod:handedOverToNarratorCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='444']">
        <!-- Integer -->
        <dd property="nlbprod:handedOverToNarratorDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='445']">
        <!-- Boolean -->
        <dd property="nlbprod:generateReceiptCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='446']">
        <!-- String -->
        <dd property="nlbprod:producerCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='447']">
        <!-- Boolean -->
        <dd property="nlbprod:narrationCompleteCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='448']">
        <!-- Integer -->
        <dd property="nlbprod:narrationCompleteDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='449']">
        <!-- String -->
        <dd property="nlbprod:feeModelCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='450']">
        <!-- Integer -->
        <dd property="nlbprod:narrationTimeCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='451']">
        <!-- Number -->
        <dd property="nlbprod:narrationTimeInHoursCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='452']">
        <!-- Number -->
        <dd property="nlbprod:rateOtherWorkCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='453']">
        <!-- Number -->
        <dd property="nlbprod:rateExtraPreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='454']">
        <!-- Number -->
        <dd property="nlbprod:rateNarrationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='455']">
        <!-- Number -->
        <dd property="nlbprod:ratePreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='456']">
        <!-- Number -->
        <dd property="nlbprod:feeOtherWorkCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='457']">
        <!-- Number -->
        <dd property="nlbprod:feeExtraPreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='458']">
        <!-- Number -->
        <dd property="nlbprod:feePreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='459']">
        <!-- Number -->
        <dd property="nlbprod:feeNarrationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='461']">
        <!-- Integer -->
        <dd property="nlbprod:inStudioWithProducerCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='462']">
        <!-- Number -->
        <dd property="nlbprod:sumFeeCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='463']">
        <!-- Boolean -->
        <dd property="nlbprod:postProductionStarted" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='464']">
        <!-- Integer -->
        <dd property="nlbprod:postProductionStartedDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='465']">
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionStarted" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='466']">
        <!-- Boolean -->
        <dd property="nlbprod:feeClaimHandled" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='467']">
        <!-- Integer -->
        <dd property="nlbprod:feeClaimHandledDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='468']">
        <!-- String -->
        <dd property="nlbprod:signatureFeeClaimHandled" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="/qdbapi/table/lusers/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='469']">
        <!-- String -->
        <dd property="nlbprod:epub3" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='470']">
        <!-- String -->
        <dd property="nlbprod:ebook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='471']">
        <!-- String -->
        <dd property="nlbprod:daisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='472']">
        <!-- String -->
        <dd property="nlbprod:braille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='473']">
        <!-- Boolean -->
        <dd property="nlbprod:bokbasen" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='474']">
        <!-- String -->
        <dd property="nlbprod:statusIcon" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='475']">
        <!-- String -->
        <dd property="nlbprod:status" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='476']">
        <!-- Number -->
        <dd property="nlbprod:pricePerPage" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='477']">
        <!-- Number -->
        <dd property="nlbprod:totalPriceForEpubProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='479']">
        <!-- String -->
        <dd property="nlbprod:dcCreator" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='480']">
        <!-- Number -->
        <dd property="nlbprod:multivolumeNumberOfCDs" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='481']">
        <!-- Boolean -->
        <dd property="nlbprod:narratedFulltext" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='482']">
        <!-- Boolean -->
        <dd property="nlbprod:ocrChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='483']">
        <!-- Boolean -->
        <dd property="nlbprod:metadataChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='484']">
        <!-- Boolean -->
        <dd property="nlbprod:structureChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='485']">
        <!-- Boolean -->
        <dd property="nlbprod:editingInstructionsChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='record_id']">
        <!-- Integer -->
        <dd property="nlbprod:record_id" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>

</xsl:stylesheet>
