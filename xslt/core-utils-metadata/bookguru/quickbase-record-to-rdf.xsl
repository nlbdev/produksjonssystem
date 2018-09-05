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
    
    <xsl:output indent="yes" method="xhtml" include-content-type="no"/>
    
    <xsl:param name="output-rdfa" select="false()"/>
    <xsl:param name="include-source-reference" select="false()"/>
    <xsl:param name="include-dc-identifier" select="false()"/>
    
    <xsl:variable name="fields" select="/qdbapi/table/fields" as="element()?"/>
    <xsl:variable name="lusers" select="/qdbapi/table/lusers" as="element()?"/>
    
    <xsl:template name="test">
        <xsl:param name="qdbapi" as="element()"/>
        <xsl:variable name="metadata" as="node()*">
            <xsl:for-each select="$qdbapi">
                <xsl:call-template name="metadata"/>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="resource-creativeWork" select="f:resource($metadata, 'creativeWork')"/>
        
        <_ xmlns="">
            <xsl:call-template name="rdfa">
                <xsl:with-param name="metadata" select="$metadata"/>
                <xsl:with-param name="resource-creativeWork" select="$resource-creativeWork"/>
            </xsl:call-template>
            <xsl:call-template name="rdfxml">
                <xsl:with-param name="metadata" select="$metadata"/>
                <xsl:with-param name="resource-creativeWork" select="$resource-creativeWork"/>
            </xsl:call-template>
        </_>
    </xsl:template>
    
    <xsl:template match="/qdbapi">
        <xsl:variable name="metadata" as="node()*">
            <xsl:call-template name="metadata"/>
        </xsl:variable>
        
        <xsl:variable name="resource-creativeWork" select="f:resource($metadata, 'creativeWork')"/>
        
        <xsl:choose>
            <xsl:when test="$output-rdfa">
                <xsl:call-template name="rdfa">
                    <xsl:with-param name="metadata" select="$metadata"/>
                    <xsl:with-param name="resource-creativeWork" select="$resource-creativeWork"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="rdfxml">
                    <xsl:with-param name="metadata" select="$metadata"/>
                    <xsl:with-param name="resource-creativeWork" select="$resource-creativeWork"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="metadata" as="node()*">
        <xsl:for-each select=".//f">
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
                    <xsl:variable name="book" select="(../f[@id='13'])[1]" as="xs:string?"/>
                    <xsl:variable name="metadata-source" select="concat('Quickbase Record@', $book, ' ', $label)"/>
                    <xsl:message select="concat('Ingen regel for QuickBase-felt i Record-tabell: ', @id, '(', $metadata-source, ')')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="rdfa" as="element()">
        <xsl:param name="metadata" as="node()*"/>
        <xsl:param name="resource-creativeWork" as="xs:string"/>
        
        <html>
            <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
            <xsl:namespace name="schema" select="'http://schema.org/'"/>
            <xsl:namespace name="nlbprod" select="'http://www.nlb.no/production'"/>
            <xsl:namespace name="nlb" select="'http://www.nlb.no/'"/>
            <head>
                <title><xsl:value-of select="$metadata[self::html:dd[@property='nlbprod:title']]"/></title>
                <meta charset="utf-8"/>
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
    </xsl:template>
    
    <xsl:template name="rdfxml" as="element()">
        <xsl:param name="metadata" as="node()*"/>
        <xsl:param name="resource-creativeWork" as="xs:string"/>
        
        <rdf:RDF>
            <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
            <xsl:namespace name="schema" select="'http://schema.org/'"/>
            <xsl:namespace name="nlbprod" select="'http://www.nlb.no/production'"/>
            <xsl:namespace name="nlb" select="'http://www.nlb.no/'"/>
            <rdf:Description>
                <xsl:attribute name="rdf:{if (matches($resource-creativeWork,'^(http|urn)')) then 'about' else 'ID'}" select="$resource-creativeWork"/>
                <rdf:type rdf:resource="http://schema.org/CreativeWork"/>
                <xsl:call-template name="list-metadata-rdfxml">
                    <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                    <xsl:with-param name="type-id" select="'creativeWork'"/>
                </xsl:call-template>
            </rdf:Description>
            <xsl:for-each select="distinct-values($metadata/@_type-id[not(.='creativeWork')])">
                <xsl:variable name="type-id" select="."/>
                <rdf:Description>
                    <xsl:variable name="resource" select="f:resource($metadata, $type-id)"/>
                    <xsl:attribute name="rdf:{if (matches($resource,'^(http|urn)')) then 'about' else 'ID'}" select="$resource"/>
                    <rdf:type rdf:resource="http://schema.org/Book"/>
                    <schema:exampleOfWork rdf:resource="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                    <xsl:if test="$include-dc-identifier">
                        <xsl:for-each select="$metadata[@_type-id = $type-id and matches(@property,'^nlbprod:identifier.[^\.]*$') and text() != ''][1]">
                            <dc:identifier>
                                <xsl:value-of select="text()"/>
                            </dc:identifier>
                        </xsl:for-each>
                    </xsl:if>
                    <xsl:call-template name="list-metadata-rdfxml">
                        <xsl:with-param name="metadata" select="$metadata[self::*]"/>
                        <xsl:with-param name="type-id" select="$type-id"/>
                    </xsl:call-template>
                </rdf:Description>
            </xsl:for-each>
        </rdf:RDF>
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
        <xsl:param name="metadata" as="element()*"/>
        <xsl:param name="type-id" as="xs:string"/>
        <xsl:variable name="identifier" select="($metadata[self::html:dd[@_type-id=$type-id and starts-with(@property,'nlbprod:identifier') and normalize-space(.)]])[1]/normalize-space(.)"/>
        <xsl:choose>
            <xsl:when test="$identifier">
                <xsl:value-of select="concat('http://websok.nlb.no/cgi-bin/websok?tnr=', $identifier)"/>
            </xsl:when>
            <xsl:when test="$type-id = 'creativeWork' and count($metadata[self::html:dd[@property=('nlbprod:originalISBN', 'nlbprod:dcSourceUrnIsbn') and normalize-space(.)]])">
                <xsl:value-of select="concat('urn:isbn:', ($metadata[self::html:dd[@property=('nlbprod:originalISBN', 'nlbprod:dcSourceUrnIsbn') and normalize-space(.)]])[1]/replace(normalize-space(.),'[^\d]',''))"/>
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
        <dt _field_type="{($fields, ancestor::qdbapi/table/fields)[1]/field[@id=$id]/@field_type}" _base_type="{($fields, ancestor::qdbapi/table/fields)[1]/field[@id=$id]/@base_type}">
            <xsl:if test="$include-source-reference">
                <xsl:variable name="label" select="($fields, ancestor::qdbapi/table/fields)[1]/field[@id=current()/@id]/label" as="xs:string?"/>
                <xsl:variable name="book" select="(../f[@id='13'])[1]" as="xs:string?"/>
                <xsl:attribute name="nlb:metadata-source" select="concat('Quickbase Record@', $book, ' ', $label)"/>
            </xsl:if>
            
            <xsl:value-of select="($fields, ancestor::qdbapi/table/fields)[1]/field[@id=$id]/label"/>
        </dt>
        <xsl:next-match/>
    </xsl:template>
    
    <xsl:template match="f[@id='1']">
        <!-- "Date Created" -->
        <!-- Integer -->
        <dd property="nlbprod:dateCreated" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='2']">
        <!-- "Date Modified" -->
        <!-- Integer -->
        <dd property="nlbprod:dateModified" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='3']">
        <!-- "Record ID#" -->
        <!-- Integer -->
        <dd property="nlbprod:recordId" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='4']">
        <!-- "Record Owner" -->
        <!-- String -->
        <dd property="nlbprod:recordOwner" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='5']">
        <!-- "Last Modified By" -->
        <!-- String -->
        <dd property="nlbprod:lastModifiedBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='6']">
        <!-- "Registreringsdato" -->
        <!-- Integer -->
        <dd property="nlbprod:registrationDate" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='7']">
        <!-- "Opprettet av" -->
        <!-- String -->
        <dd property="nlbprod:createdBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='8']">
        <!-- "Tittel" -->
        <!-- String -->
        <dd property="nlbprod:title" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='9']">
        <!-- "Forfatter" -->
        <!-- String -->
        <dd property="nlbprod:author" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='10']">
        <!-- "Forlag" -->
        <!-- String -->
        <dd property="nlbprod:publisher" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='11']">
        <!-- "Original ISBN" -->
        <!-- String -->
        <dd property="schema:isbn" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='12']">
        <!-- "Production turnaround time" -->
        <!-- String -->
        <dd property="nlbprod:productionTurnaroundTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='13']">
        <!-- "Tilvekstnummer EPUB" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.epub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='14']">
        <!-- "EPUB ferdig katalogisert" -->
        <!-- Boolean -->
        <dd property="nlbprod:epubCatalogued" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='15']">
        <!-- "PDF/grunnlagsfil mottatt og lagret" -->
        <!-- Boolean -->
        <dd property="nlbprod:sourceFileReceived" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='16']">
        <!-- "Producer" -->
        <!-- String -->
        <dd property="nlbprod:producer" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='17']">
        <!-- "Production approved" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionApproved" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='18']">
        <!-- "Antall sider" -->
        <!-- Integer -->
        <dd property="nlbprod:numberOfPages" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='19']">
        <!-- "Number of images" -->
        <!-- Integer -->
        <dd property="nlbprod:numberOfImages" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='20']">
        <!-- "Tilvekstnummer DAISY 2.02 Skjønnlitteratur" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='21']">
        <!-- "NLB ISBN DAISY 2.02 Skjønnlitteratur" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnDaisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='22']">
        <!-- "Format: DAISY 2.02 Innlest Skjønn" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narrated" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='23']">
        <!-- "Format: DAISY 2.02 TTS Skjønn" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202tts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='24']">
        <!-- "Tilvekstnummer DAISY 2.02 Studielitteratur" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202.student" _type-id="audio" id="identifier-daisy202student">
            <xsl:value-of select="."/>
        </dd>
        <!--<dd property="dcterms:audience" _type-id="audio" refines="#identifier-daisy202student">Student</dd>-->
    </xsl:template>
    
    <xsl:template match="f[@id='25']">
        <!-- "NLB ISBN DAISY 2.02 Studielitteratur" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnDaisy202student" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='26']">
        <!-- "Format: DAISY 2.02 Innlest Studie" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narratedStudent" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='27']">
        <!-- "Format: DAISY 2.02 TTS Studie" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202ttsStudent" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='28']">
        <!-- "Tilvekstnummer Punktskrift" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.braille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='29']">
        <!-- "NLB ISBN Punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='30']">
        <!-- "Format: Punktskrift" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='31']">
        <!-- "Tilvekstnummer DAISY 2.02 Innlest fulltekst" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202.fulltext" _type-id="audio" id="identifier-daisy202narratedfulltext">
            <xsl:value-of select="."/>
        </dd>
        <!--<dd property="dc:type" _type-id="audio" refines="#identifier-daisy202narratedfulltext">Narrated Fulltext</dd>-->
    </xsl:template>
    
    <xsl:template match="f[@id='32']">
        <!-- "Tilvekstnummer e-bok" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.ebook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='33']">
        <!-- "Format: DAISY 2.02 Innlest fulltekst" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narratedFulltext" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='36']">
        <!-- "NLB ISBN E-bok" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnEbook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='37']">
        <!-- "Format: E-bok" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatEbook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='38']">
        <!-- "Tilvekstnummer ekstern produksjon" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.external" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='40']">
        <!-- "Tilrettelagt for innlesing" -->
        <!-- Boolean -->
        <dd property="nlbprod:preparedForNarration" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='41']">
        <!-- "DAISY 2.02 ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:daisy202productionComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='42']">
        <!-- "DAISY 2.02 TTS ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:daisy202ttsProductionComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='43']">
        <!-- "Punktskrift ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='44']">
        <!-- "E-bok ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:ebookProductionComplete" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='46']">
        <!-- "Levert innleser" -->
        <!-- Boolean -->
        <dd property="nlbprod:handedOverToNarrator" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='47']">
        <!-- "Tidspunkt for siste endring" -->
        <!-- Integer -->
        <dd property="nlbprod:timeForLastChange" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='48']">
        <!-- "Sist endret av:" -->
        <!-- String -->
        <dd property="nlbprod:lastChangedBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='49']">
        <!-- "Produksjoner ID#" -->
        <!-- Integer -->
        <dd property="nlbprod:productionsId" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='51']">
        <!-- "Kommentar katalogisering" -->
        <!-- String -->
        <dd property="nlbprod:commentCatalogization" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='55']">
        <!-- "PDF/grunnlagsfil bestilt" -->
        <!-- Boolean -->
        <dd property="nlbprod:sourceFileOrdered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='56']">
        <!-- "Katalogiseringsdato EPUB" -->
        <!-- Integer -->
        <dd property="nlbprod:catalogizationDateEpub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='58']">
        <!-- "WIPS ISBN" -->
        <!-- String -->
        <dd property="nlbprod:wipsIsbn" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='60']">
        <!-- "Til manuell tilrettelegging i NLB" -->
        <!-- Boolean -->
        <dd property="nlbprod:forManualPreparationInNLB" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='61']">
        <!-- "Production approved date" -->
        <!-- Integer -->
        <dd property="nlbprod:productionApprovedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='62']">
        <!-- "Order date" -->
        <!-- Integer -->
        <dd property="nlbprod:orderDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='63']">
        <!-- "Innleser" -->
        <!-- String -->
        <dd property="nlbprod:narrator" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='64']">
        <!-- "Innlest tid" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='65']">
        <!-- "Levert innleser dato" -->
        <!-- Integer -->
        <dd property="nlbprod:handedOverToNarratorDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='66']">
        <!-- "Student" -->
        <!-- String -->
        <dd property="nlbprod:student" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='67']">
        <!-- "Genre" -->
        <!-- String -->
        <dd property="nlbprod:genre" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='68']">
        <!-- "Ferdig innlest" -->
        <!-- Boolean -->
        <dd property="nlbprod:narrationComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='69']">
        <!-- "Ferdig innlest dato" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationCompletionDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='71']">
        <!-- "Avtalt ferdig innlest dato" -->
        <!-- Integer -->
        <dd property="nlbprod:agreedNarrationCompletionDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='73']">
        <!-- "Tilrettelagt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:preparedDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='74']">
        <!-- "Produsent" -->
        <!-- String -->
        <dd property="nlbprod:producer2" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='77']">
        <!-- "Format: DAISY 2.02 WIPS" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202wips" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='80']">
        <!-- "Add Record" -->
        <!-- String -->
        <dd property="nlbprod:addRecord" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='81']">
        <!-- "PDF/Grunnlagsfil bestilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:sourceFileOrderedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='82']">
        <!-- "PDF/Grunnlagsfil mottatt/skannet dato" -->
        <!-- Integer -->
        <dd property="nlbprod:sourceFileReceivedOrScannedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='83']">
        <!-- "PDF/Grunnlagsfil format" -->
        <!-- String -->
        <dd property="nlbprod:sourceFileFormat" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='84']">
        <!-- "EPUB/DTBook ordered" -->
        <!-- Boolean -->
        <dd property="nlbprod:epubDTBookOrdered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='85']">
        <!-- "DAISY 2.02 ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202ProductionCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='86']">
        <!-- "DAISY 2.02 TTS ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202ttsProductionCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='87']">
        <!-- "Punktskrift ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='88']">
        <!-- "E-bok ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:ebookProductionCompleteDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='97']">
        <!-- "Honorar pr ferdig innlest tid" -->
        <!-- Number -->
        <dd property="nlbprod:feeNarratedTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='98']">
        <!-- "Honorar forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:feePreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='99']">
        <!-- "Tillegg kveld og helg" -->
        <!-- Number -->
        <dd property="nlbprod:additionalFeeNightAndWeekend" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='103']">
        <!-- "Innlest tid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:narratedTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='116']">
        <!-- "Forberedelsestid" -->
        <!-- Integer -->
        <dd property="nlbprod:preparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='117']">
        <!-- "Kvelds- og helgetillegg" -->
        <!-- Integer -->
        <dd property="nlbprod:additionalNightAndWeekend" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='119']">
        <!-- "Forberedelsestid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:preparationTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='120']">
        <!-- "Kvelds- og helgetillegg i timer" -->
        <!-- Number -->
        <dd property="nlbprod:nightAndWeekendInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='122']">
        <!-- "Sum honorar" -->
        <!-- Number -->
        <dd property="nlbprod:sumFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='131']">
        <!-- "Annet arbeid for NLB" -->
        <!-- Integer -->
        <dd property="nlbprod:otherWorkForNLB" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='137']">
        <!-- "Ferdig honorert" -->
        <!-- Boolean -->
        <dd property="nlbprod:feeComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='138']">
        <!-- "Ferdig honorert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:feeCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='139']">
        <!-- "Annet arbeid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:otherWorkInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='141']">
        <!-- "Forskudd" -->
        <!-- Number -->
        <dd property="nlbprod:advancePayment" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='142']">
        <!-- "Total sum honorar" -->
        <!-- Number -->
        <dd property="nlbprod:totalSumFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='143']">
        <!-- "Dato for forskuddsbetaling" -->
        <!-- Integer -->
        <dd property="nlbprod:advancePaymentDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='145']">
        <!-- "Honorar annet arbeid" -->
        <!-- Number -->
        <dd property="nlbprod:feeOtherWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='146']">
        <!-- "DAISY 2.02 klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:daisy202readyForLoan" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='147']">
        <!-- "DAISY 2.02 klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202readyForLoanDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='148']">
        <!-- "Kommentar innlesing" -->
        <!-- String -->
        <dd property="nlbprod:narrationComment" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='149']">
        <!-- "Punktskrift klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='150']">
        <!-- "Punktskrift klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='151']">
        <!-- "E-bok klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:ebookReadyForLoan" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='152']">
        <!-- "E-bok klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:EBOOKReadyForLoanDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='153']">
        <!-- "Bestillingsskjema ekstern produksjon" -->
        <!-- String -->
        <dd property="nlbprod:orderFormExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='154']">
        <!-- "DTBook sendt i retur" -->
        <!-- Boolean -->
        <dd property="nlbprod:dtbookReturned" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='155']">
        <!-- "DTBook sendt i retur dato" -->
        <!-- Integer -->
        <dd property="nlbprod:dtbookReturnedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='156']">
        <!-- "DAISY 2.02 Skjønnlitteratur forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202ExpectedCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='157']">
        <!-- "DAISY 2.02 Studielitteratur forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202studentExpectedCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='158']">
        <!-- "Punktskrift forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleExpectedCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='159']">
        <!-- "E-bok forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:ebookProductionExpectedCompleteDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='160']">
        <!-- "Ekstern produksjon forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:externalProductionExpectedCompleteDate" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='161']">
        <!-- "Due date for production" -->
        <!-- Integer -->
        <dd property="nlbprod:dueDateForProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='163']">
        <!-- "Editing instructions" -->
        <!-- String -->
        <dd property="nlbprod:editingInstructions" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='164']">
        <!-- "Oversetter" -->
        <!-- String -->
        <dd property="nlbprod:translator" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='165']">
        <!-- "Språk" -->
        <!-- String -->
        <dd property="nlbprod:language" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='167']">
        <!-- "Delivery Control" -->
        <!-- String -->
        <dd property="nlbprod:deliveryControl" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='170']">
        <!-- "Kategori" -->
        <!-- String -->
        <dd property="nlbprod:category" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='171']">
        <!-- "Format: Noter" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatNotes" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='175']">
        <!-- "Kommentar etterarbeid" -->
        <!-- String -->
        <dd property="nlbprod:commentPostProduction" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='176']">
        <!-- "Spilletid DAISY 2.02" -->
        <!-- Integer -->
        <dd property="nlbprod:playtimeDaisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='177']">
        <!-- "Spilletid DAISY 2.02 TTS" -->
        <!-- Integer -->
        <dd property="nlbprod:playtimeDaisy202tts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='178']">
        <!-- "Format: Punktklubb" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatBrailleClub" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='180']">
        <!-- "Ikke til honorering" -->
        <!-- Boolean -->
        <dd property="nlbprod:notForFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='184']">
        <!-- "Ekstra forberedelsestid" -->
        <!-- Integer -->
        <dd property="nlbprod:extraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='185']">
        <!-- "Ekstra forberedelsestid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:extraPreparationTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='186']">
        <!-- "Honorar ekstra forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:feeExtraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='262']">
        <!-- "Generer fakturagrunnlag" -->
        <!-- Boolean -->
        <dd property="nlbprod:generateFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='268']">
        <!-- "Åpen linjeavstand" -->
        <!-- Boolean -->
        <dd property="nlbprod:openLinespacing" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='269']">
        <!-- "Punktsider" -->
        <!-- String -->
        <dd property="dc:format.extent.pages" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='270']">
        <!-- "Hefter" -->
        <!-- String -->
        <dd property="dc:format.extent.volumes" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='279']">
        <!-- "Sats ferdig innlest tid" -->
        <!-- Number -->
        <dd property="nlbprod:rateNarrationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='280']">
        <!-- "Sats forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:ratePreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='281']">
        <!-- "Sats ekstra forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:rateExtraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='282']">
        <!-- "Sats tillegg" -->
        <!-- Number -->
        <dd property="nlbprod:rateAdditionalWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='285']">
        <!-- "Sats annet arbeid" -->
        <!-- Number -->
        <dd property="nlbprod:rateOtherWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='286']">
        <!-- "Honorarmodell" -->
        <!-- String -->
        <dd property="nlbprod:feeModel" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='304']">
        <!-- "Generer kvittering" -->
        <!-- Boolean -->
        <dd property="nlbprod:generateReceipt" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='308']">
        <!-- "Ansatt nr." -->
        <!-- Number -->
        <dd property="nlbprod:employeeNumber" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='309']">
        <!-- "Konto" -->
        <!-- String -->
        <dd property="nlbprod:account" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='310']">
        <!-- "Kostnadssted" -->
        <!-- Number -->
        <dd property="nlbprod:costLocation" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='311']">
        <!-- "Overstyring" -->
        <!-- Number -->
        <dd property="nlbprod:overriding" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='312']">
        <!-- "Lønnart" -->
        <!-- Number -->
        <dd property="nlbprod:paymentType" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='314']">
        <!-- "Signatur etterarbeid DAISY 2.02" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionDaisy202" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='315']">
        <!-- "Signatur etterarbeid DAISY 2.02 TTS" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionDaisy202tts" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='316']">
        <!-- "Signatur etterarbeid punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionBraille" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='317']">
        <!-- "Signatur etterarbeid E-bok" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionEbook" _type-id="ebook">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='318']">
        <!-- "Enkeltsidig trykk" -->
        <!-- Boolean -->
        <dd property="nlbprod:singlePagePrint" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='319']">
        <!-- "Punktklubb ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleClubProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='320']">
        <!-- "Punktklubb ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleClubProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='321']">
        <!-- "Signatur etterarbeid punktklubb" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionBrailleClub" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='323']">
        <!-- "Signatur tilrettelegging" -->
        <!-- String -->
        <dd property="nlbprod:signaturePreparation" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='324']">
        <!-- "Signatur DAISY 2.02 klargjort for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureDaisy202readyForLoan" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='325']">
        <!-- "Signatur E-bok klargjort for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureEbookReadyForLoan" _type-id="ebook">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='326']">
        <!-- "Signatur punktskrift klargjort for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureBrailleReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='327']">
        <!-- "Punktklubb klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleClubReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='328']">
        <!-- "Punktklubb klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleClubReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='329']">
        <!-- "Signatur punktklubb klargjort for utån" -->
        <!-- String -->
        <dd property="nlbprod:signatureBrailleClubReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='330']">
        <!-- "Priskategori" -->
        <!-- String -->
        <dd property="nlbprod:priceCategory" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='342']">
        <!-- "E-post forlagskontakt" -->
        <!-- String -->
        <dd property="nlbprod:emailPublisherContact" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='343']">
        <!-- "E-post student" -->
        <!-- String -->
        <dd property="nlbprod:emailStudent" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='344']">
        <!-- "Signatur DTBook bestilt" -->
        <!-- String -->
        <dd property="nlbprod:signatureDTBookOrdered" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='345']">
        <!-- "Format: DAISY 2.02 ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202externalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='346']">
        <!-- "Format: E-bok ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatEbookExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='347']">
        <!-- "Format: Audio CD WAV ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatAudioCDWAVExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='348']">
        <!-- "Format: Audio CD MP3 ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatAudioCDMP3ExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='349']">
        <!-- "Format: Annet format ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatOtherExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='350']">
        <!-- "Kommentar ekstern produksjon" -->
        <!-- String -->
        <dd property="nlbprod:commentExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='351']">
        <!-- "Ekstern produksjon ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:externalProductionProductionComplete" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='352']">
        <!-- "Ekstern produksjon ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:externalProductionProductionCompleteDate" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='353']">
        <!-- "Signatur etterarbeid ekstern produksjon" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionExternalProduction" _type-id="external">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='354']">
        <!-- "Spilletid ekstern produksjon" -->
        <!-- Integer -->
        <dd property="nlbprod:playtimeExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='357']">
        <!-- "Honorering av flere innlesere" -->
        <!-- String -->
        <dd property="nlbprod:feeForMultipleNarrators" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='360']">
        <!-- "Signatur levert innleser" -->
        <!-- String -->
        <dd property="nlbprod:signatureDeliveredToNarrator" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='362']">
        <!-- "Duplikat" -->
        <!-- Boolean -->
        <dd property="nlbprod:duplicate" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='366']">
        <!-- "Til delproduksjon punktskrift" -->
        <!-- Boolean -->
        <dd property="nlbprod:partialBrailleProduction" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='367']">
        <!-- "Format: Punktskrift delproduksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatBraillePartialProduction" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='368']">
        <!-- "Format: Taktil trykk" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatTactilePrint" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='370']">
        <!-- "Kommentar punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:commentBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='371']">
        <!-- "Taktilt trykk klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:tactilePrintReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='372']">
        <!-- "Taktilt trykk klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:tactilePrintReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='374']">
        <!-- "Taktilt trykk ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:tactilePrintProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='375']">
        <!-- "Taktilt trykk ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:tactilePrintProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='377']">
        <!-- "Signatur taktilt trykk ferdig produsert" -->
        <!-- String -->
        <dd property="nlbprod:signatureTactilePrintProductionComplete" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='378']">
        <!-- "Signatur taktilt trykk klar for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureTactilePrintReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='379']">
        <!-- "Venting pga. teknisk feil" -->
        <!-- Integer -->
        <dd property="nlbprod:waitingBecauseOfTechnicalProblems" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='380']">
        <!-- "I studio med produsent" -->
        <!-- Integer -->
        <dd property="nlbprod:inStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='381']">
        <!-- "Sats ventetid" -->
        <!-- Number -->
        <dd property="nlbprod:rateWaitingTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='382']">
        <!-- "Sats i studio med produsent" -->
        <!-- Number -->
        <dd property="nlbprod:rateInStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='383']">
        <!-- "Venting pga teknisk feil i timer" -->
        <!-- Number -->
        <dd property="nlbprod:waitingBecauseOfTechnicalProblemsInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='384']">
        <!-- "I studio med produsent i timer" -->
        <!-- Number -->
        <dd property="nlbprod:inStudioWithProducerInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='385']">
        <!-- "Kompensasjon ventetid" -->
        <!-- Number -->
        <dd property="nlbprod:compensationWaitingTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='386']">
        <!-- "Kompensasjon i studio med produsent" -->
        <!-- Number -->
        <dd property="nlbprod:compensationInStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='387']">
        <!-- "Source file" -->
        <!-- String -->
        <dd property="nlbprod:sourceFile" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='388']">
        <!-- "Estimated book category" -->
        <!-- String -->
        <dd property="nlbprod:estimatedBookCategory" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='389']">
        <!-- "Book category" -->
        <!-- String -->
        <dd property="nlbprod:bookCategory" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='390']">
        <!-- "Number of pages" -->
        <!-- Integer -->
        <dd property="nlbprod:numberOfPages2" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='392']">
        <!-- "Upload EPUB 3 file" -->
        <!-- String -->
        <dd property="nlbprod:uploadEpub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='393']">
        <!-- "Production delivered" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionDelivered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='395']">
        <!-- "Production delivery date" -->
        <!-- Integer -->
        <dd property="nlbprod:productionDeliveryDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='396']">
        <!-- "Agency" -->
        <!-- String -->
        <dd property="nlbprod:agency" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='397']">
        <!-- "Production number-UID" -->
        <!-- Number -->
        <dd property="nlbprod:productionNumberUID" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='398']">
        <!-- "Leave a message" -->
        <!-- Boolean -->
        <dd property="nlbprod:leaveAMessage" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='399']">
        <!-- "Production Questions and Notes" -->
        <!-- String -->
        <dd property="nlbprod:productionQuestionsAndNotes" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='402']">
        <!-- "Kommentar bestilling" -->
        <!-- String -->
        <dd property="nlbprod:commentOrder" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='403']">
        <!-- "Purchase order ID" -->
        <!-- String -->
        <dd property="nlbprod:purchaseOrderId" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='405']">
        <!-- "ASCIIMath" -->
        <!-- Boolean -->
        <dd property="nlbprod:asciimath" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='406']">
        <!-- "Source file format" -->
        <!-- String -->
        <dd property="nlbprod:sourceFileFormat2" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='407']">
        <!-- "Alternate source file URL" -->
        <!-- String -->
        <dd property="nlbprod:alternateSourceFileURL" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='408']">
        <!-- "Exercises and answers" -->
        <!-- Boolean -->
        <dd property="nlbprod:exercisesAndAnswers" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='409']">
        <!-- "Inline text styling" -->
        <!-- Boolean -->
        <dd property="nlbprod:inlineTextStyling" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='410']">
        <!-- "Extraction of text content in images" -->
        <!-- Boolean -->
        <dd property="nlbprod:extractionOfTextContentInImages" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='413']">
        <!-- "Production returned" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionReturned" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='414']">
        <!-- "Production return date" -->
        <!-- Integer -->
        <dd property="nlbprod:productionReturnDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='415']">
        <!-- "Kommentar EPUB-bestilling" -->
        <!-- String -->
        <dd property="nlbprod:commentEpubOrder" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='416']">
        <!-- "Production downloaded" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionDownloaded" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='417']">
        <!-- "Downloaded date" -->
        <!-- Integer -->
        <dd property="nlbprod:downloadedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='418']">
        <!-- "Signatur for nedlasting" -->
        <!-- String -->
        <dd property="nlbprod:signatureForDownload" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='419']">
        <!-- "Pages" -->
        <!-- Integer -->
        <dd property="nlbprod:pages" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='420']">
        <!-- "Title" -->
        <!-- String -->
        <dd property="nlbprod:title2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='421']">
        <!-- "Author" -->
        <!-- String -->
        <dd property="nlbprod:author2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='422']">
        <!-- "Contributor" -->
        <!-- String -->
        <dd property="nlbprod:contributor" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='423']">
        <!-- "Language" -->
        <!-- String -->
        <dd property="nlbprod:language2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='426']">
        <!-- "Signatur godkjent produksjon" -->
        <!-- String -->
        <dd property="nlbprod:signatureApprovedProduction" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='427']">
        <!-- "Signatur returnert produksjon" -->
        <!-- String -->
        <dd property="nlbprod:signatureReturnedProduction" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='428']">
        <!-- "Validation log file" -->
        <!-- String -->
        <dd property="nlbprod:validationLogFile" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='429']">
        <!-- "Original ISSN" -->
        <!-- String -->
        <dd property="nlbprod:originalISSN" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='430']">
        <!-- "Hefte nr" -->
        <!-- String -->
        <dd property="nlbprod:volumeNumber" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='431']">
        <!-- "<dc:source>urn:isbn:" -->
        <!-- String -->
        <dd property="nlbprod:dcSourceUrnIsbn" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='432']">
        <!-- "Hasteproduksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:urgentProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='434']">
        <!-- "Kvelds- og helgetillegg prosent av total tid" -->
        <!-- Number -->
        <dd property="nlbprod:nightAndWeekendPercentageOfTotalTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='436']">
        <!-- "Signatur honorering" -->
        <!-- String -->
        <dd property="nlbprod:signatureFee" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='437']">
        <!-- "Signatur registrering" -->
        <!-- String -->
        <dd property="nlbprod:signatureRegistration" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='438']">
        <!-- "Ny registrering" -->
        <!-- Boolean -->
        <dd property="nlbprod:newRegistration" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='439']">
        <!-- "Innleser_copy" -->
        <!-- String -->
        <dd property="nlbprod:narratorCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='440']">
        <!-- "Ansatt nr._copy" -->
        <!-- Number -->
        <dd property="nlbprod:employeeNumberCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='442']">
        <!-- "Avtalt ferdig innlest dato_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:agreedNarrationCompletionDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='443']">
        <!-- "Levert innleser_copy" -->
        <!-- Boolean -->
        <dd property="nlbprod:handedOverToNarratorCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='444']">
        <!-- "Levert innleser dato_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:handedOverToNarratorDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='445']">
        <!-- "Generer kvittering_copy" -->
        <!-- Boolean -->
        <dd property="nlbprod:generateReceiptCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='446']">
        <!-- "Produsent_copy" -->
        <!-- String -->
        <dd property="nlbprod:producerCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='447']">
        <!-- "Ferdig innlest_copy" -->
        <!-- Boolean -->
        <dd property="nlbprod:narrationCompleteCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='448']">
        <!-- "Ferdig innlest dato_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationCompleteDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='449']">
        <!-- "Honorarmodell_copy" -->
        <!-- String -->
        <dd property="nlbprod:feeModelCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='450']">
        <!-- "Innlest tid_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationTimeCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='451']">
        <!-- "Innlest tid i timer_copy" -->
        <!-- Number -->
        <dd property="nlbprod:narrationTimeInHoursCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='452']">
        <!-- "Sats annet arbeid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:rateOtherWorkCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='453']">
        <!-- "Sats ekstra forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:rateExtraPreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='454']">
        <!-- "Sats ferdig innlest tid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:rateNarrationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='455']">
        <!-- "Sats forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:ratePreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='456']">
        <!-- "Honorar annet arbeid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feeOtherWorkCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='457']">
        <!-- "Honorar ekstra forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feeExtraPreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='458']">
        <!-- "Honorar forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feePreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='459']">
        <!-- "Honorar pr ferdig innlest tid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feeNarrationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='461']">
        <!-- "I studio med produsent_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:inStudioWithProducerCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='462']">
        <!-- "Sum honorar_copy" -->
        <!-- Number -->
        <dd property="nlbprod:sumFeeCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='463']">
        <!-- "Etterarbeid startet" -->
        <!-- Boolean -->
        <dd property="nlbprod:postProductionStarted" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='464']">
        <!-- "Etterarbeid startet dato" -->
        <!-- Integer -->
        <dd property="nlbprod:postProductionStartedDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='465']">
        <!-- "Signatur for påbegynt etterarbeid" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionStarted" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='466']">
        <!-- "Honorarkrav behandlet" -->
        <!-- Boolean -->
        <dd property="nlbprod:feeClaimHandled" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='467']">
        <!-- "Honorarkrav behandlet dato" -->
        <!-- Integer -->
        <dd property="nlbprod:feeClaimHandledDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='468']">
        <!-- "Signatur honorarkrav behandlet" -->
        <!-- String -->
        <dd property="nlbprod:signatureFeeClaimHandled" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='469']">
        <!-- "EPUB3" -->
        <!-- String -->
        <dd property="nlbprod:epub3" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='470']">
        <!-- "E-bok" -->
        <!-- String -->
        <dd property="nlbprod:ebook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='471']">
        <!-- "DAISY 2.02" -->
        <!-- String -->
        <dd property="nlbprod:daisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='472']">
        <!-- "Punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:braille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='473']">
        <!-- "www.bokbasen.no" -->
        <!-- Boolean -->
        <dd property="nlbprod:bokbasen" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='474']">
        <!-- "Statusikon" -->
        <!-- String -->
        <dd property="nlbprod:statusIcon" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='475']">
        <!-- "Status" -->
        <!-- String -->
        <dd property="nlbprod:status" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='476']">
        <!-- "Pris per side" -->
        <!-- Number -->
        <dd property="nlbprod:pricePerPage" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='477']">
        <!-- "Total pris for EPUB-produksjon ()" -->
        <!-- Number -->
        <dd property="nlbprod:totalPriceForEpubProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='479']">
        <!-- "<dc:creator>" -->
        <!-- String -->
        <dd property="nlbprod:dcCreator" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='480']">
        <!-- "Multivolum antall CDer" -->
        <!-- Number -->
        <dd property="nlbprod:multivolumeNumberOfCDs" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='481']">
        <!-- "Lydbok med tekst" -->
        <!-- Boolean -->
        <dd property="nlbprod:narratedFulltext" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='482']">
        <!-- "OCR-kontroll utført" -->
        <!-- Boolean -->
        <dd property="nlbprod:ocrChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='483']">
        <!-- "Metadata kontrollert" -->
        <!-- Boolean -->
        <dd property="nlbprod:metadataChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='484']">
        <!-- "Struktur kontrollert" -->
        <!-- Boolean -->
        <dd property="nlbprod:structureChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='485']">
        <!-- "Editing instructions kontrollert" -->
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
