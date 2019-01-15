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
    <xsl:param name="include-dc-identifier" select="false()"/>
    <xsl:param name="library" select="'nlb'"/>
    
    <xsl:variable name="fields" select="/qdbapi/table/fields" as="element()?"/>
    <xsl:variable name="lusers" select="/qdbapi/table/lusers" as="element()?"/>
    
    <xsl:template name="test">
        <xsl:param name="qdbapi" as="element()"/>
        <xsl:param name="library" as="xs:string" select="$library"/>
        <xsl:variable name="metadata" as="node()*">
            <xsl:for-each select="$qdbapi">
                <xsl:call-template name="metadata">
                    <xsl:with-param name="library" select="$library"/>
                </xsl:call-template>
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
            <xsl:call-template name="metadata">
                <xsl:with-param name="library" select="$library"/>
            </xsl:call-template>
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
        <xsl:param name="library" as="xs:string"/>
        <xsl:for-each select=".//f">
            <xsl:sort select="@id"/>
            <xsl:variable name="meta" as="node()*">
                <xsl:choose>
                    <xsl:when test="lower-case($library) = 'statped'">
                        <xsl:apply-templates select="." mode="statped"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="." mode="nlb"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:choose>
                <xsl:when test="$meta[self::html:dd]">
                    <xsl:copy-of select="$meta"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="label" select="/qdbapi/table/fields/field[@id=current()/@id]/label" as="xs:string?"/>
                    <xsl:variable name="book" select="(../f[@id='13'])[1]" as="xs:string?"/>
                    <xsl:variable name="metadata-source" select="concat('Quickbase Record@', $book, ' ', $label)"/>
                    <xsl:message select="concat('Ingen regel for QuickBase-felt i Record-tabell: ', @id, ' (', $library, ' - ', $metadata-source, ')')"/>
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
                        <xsl:for-each select="f:identifier-elements($metadata, $type-id)[1]">
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
        <xsl:variable name="identifier-elements" select="f:identifier-elements($metadata, $type-id)"/>
        <xsl:variable name="identifier" select="$identifier-elements[1]/normalize-space(.)"/>
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
    
    <xsl:function name="f:identifier-elements" as="element()*">
        <xsl:param name="metadata" as="element()*"/>
        <xsl:param name="type-id" as="xs:string"/>
        
        <!-- return nlbprod:identifier.daisy202 before nlbprod:identifier.daisy202.student, and return nlbprod:identifier.reserved last -->
        <xsl:variable name="identifier-elements" select="$metadata[self::html:dd[@_type-id=$type-id and starts-with(@property,'nlbprod:identifier') and normalize-space(.)]]"/>
        <xsl:variable name="identifier-elements" select="($identifier-elements[matches(@property,'^nlbprod:identifier\.[^\.]*$')], $identifier-elements[not(matches(@property,'^nlbprod:identifier\.[^\.]*$'))])"/>
        <xsl:variable name="identifier-elements" select="($identifier-elements[not(starts-with(@property, 'nlbprod:identifier.reserved'))], $identifier-elements[starts-with(@property, 'nlbprod:identifier.reserved')])"/>
        
        <xsl:sequence select="$identifier-elements"/>
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
    
    <xsl:template match="f" priority="2" mode="#all">
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
    
    <xsl:template match="f[@id='1']" mode="nlb statped">
        <!-- "Date Created" -->
        <!-- Integer -->
        <dd property="nlbprod:dateCreated" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='2']" mode="nlb statped">
        <!-- "Date Modified" -->
        <!-- Integer -->
        <dd property="nlbprod:dateModified" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='3']" mode="nlb statped">
        <!-- "Record ID#" -->
        <!-- Integer -->
        <dd property="nlbprod:recordId" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='4']" mode="nlb statped">
        <!-- "Record Owner" -->
        <!-- String -->
        <dd property="nlbprod:recordOwner" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='5']" mode="nlb statped">
        <!-- "Last Modified By" -->
        <!-- String -->
        <dd property="nlbprod:lastModifiedBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='6']" mode="nlb statped">
        <!-- "Registreringsdato" -->
        <!-- Integer -->
        <dd property="nlbprod:registrationDate" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='7']" mode="nlb statped">
        <!-- "Opprettet av" -->
        <!-- String -->
        <dd property="nlbprod:createdBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='8']" mode="nlb statped">
        <!-- "Tittel" -->
        <!-- String -->
        <dd property="nlbprod:title" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='9']" mode="nlb statped">
        <!-- "Forfatter" -->
        <!-- String -->
        <dd property="nlbprod:author" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='10']" mode="nlb statped">
        <!-- "Forlag" -->
        <!-- String -->
        <dd property="nlbprod:publisher" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='11']" mode="nlb statped">
        <!-- "Original ISBN" -->
        <!-- String -->
        <dd property="schema:isbn" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='12']" mode="nlb statped">
        <!-- "Production turnaround time" -->
        <!-- String -->
        <dd property="nlbprod:productionTurnaroundTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='13']" mode="nlb statped">
        <!-- "Tilvekstnummer EPUB" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.epub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='14']" mode="nlb statped">
        <!-- "EPUB ferdig katalogisert" -->
        <!-- Boolean -->
        <dd property="nlbprod:epubCatalogued" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='15']" mode="nlb statped">
        <!-- "PDF/grunnlagsfil mottatt og lagret" -->
        <!-- Boolean -->
        <dd property="nlbprod:sourceFileReceived" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='16']" mode="nlb statped">
        <!-- "Producer" -->
        <!-- String -->
        <dd property="nlbprod:producer" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='17']" mode="nlb statped">
        <!-- "Production approved" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionApproved" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='18']" mode="nlb statped">
        <!-- "Antall sider" -->
        <!-- Integer -->
        <dd property="nlbprod:numberOfPages" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='19']" mode="nlb statped">
        <!-- "Number of images" -->
        <!-- Integer -->
        <dd property="nlbprod:numberOfImages" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='20']" mode="nlb">
        <!-- "Tilvekstnummer DAISY 2.02 Skjønnlitteratur" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='21']" mode="nlb">
        <!-- "NLB ISBN DAISY 2.02 Skjønnlitteratur" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnDaisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='22']" mode="nlb">
        <!-- "Format: DAISY 2.02 Innlest Skjønn" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narrated" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='23']" mode="nlb">
        <!-- "Format: DAISY 2.02 TTS Skjønn" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202tts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='24']" mode="nlb">
        <!-- "Tilvekstnummer DAISY 2.02 Studielitteratur" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.daisy202.student" _type-id="audio" id="identifier-daisy202student">
            <xsl:value-of select="."/>
        </dd>
        <!--<dd property="dcterms:audience" _type-id="audio" refines="#identifier-daisy202student">Student</dd>-->
    </xsl:template>
    
    <xsl:template match="f[@id='24']" mode="statped">
        <!-- "Tilvekstnummer DAISY 2.02 Innlest" -->
        <!-- Integer -->
        
        <!--
            Hvis dette er en innlest bok, bruk 'nlbprod:identifier.daisy202', ellers 'nlbprod:identifier.daisy202.narrated'.
            Dette er for å sikre at det er riktig boknummer som brukes (ikke TTS-boknummer på innleste bøker og omvendt).
        -->
        <xsl:variable name="formatDaisy202Narrated" select="../f[@id='26']/text() = '1'" as="xs:boolean"/>
        <xsl:variable name="formatDaisy202Tts" select="../f[@id='27']/text() = '1'" as="xs:boolean"/>
        
        <dd property="nlbprod:identifier.daisy202{if ($formatDaisy202Narrated and not($formatDaisy202Tts)) then '' else '.narrated'}" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='25']" mode="nlb">
        <!-- "NLB ISBN DAISY 2.02 Studielitteratur" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnDaisy202student" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='25']" mode="statped">
        <!-- "NLB ISBN DAISY 2.02 Studielitteratur" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnDaisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='26']" mode="nlb">
        <!-- "Format: DAISY 2.02 Innlest Studie" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narratedStudent" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='26']" mode="statped">
        <!-- "Format: DAISY 2.02 Innlest" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narrated" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='27']" mode="nlb">
        <!-- "Format: DAISY 2.02 TTS Studie" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202ttsStudent" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='27']" mode="statped">
        <!-- "Format: DAISY 2.02 TTS" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202tts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='28']" mode="nlb statped">
        <!-- "Tilvekstnummer Punktskrift" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.braille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='29']" mode="nlb statped">
        <!-- "NLB ISBN Punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='30']" mode="nlb statped">
        <!-- "Format: Punktskrift" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='31']" mode="nlb statped">
        <!-- "Reservert tilvekstnummerserie (4XXXX)" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.reserved" _type-id="audio" id="identifier-daisy202narratedfulltext">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='32']" mode="nlb statped">
        <!-- "Tilvekstnummer e-bok" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.ebook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='33']" mode="nlb">
        <!-- "Format: DAISY 2.02 Innlest fulltekst" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202narratedFulltext" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='36']" mode="nlb statped">
        <!-- "NLB ISBN E-bok" -->
        <!-- String -->
        <dd property="nlbprod:nlbIsbnEbook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='37']" mode="nlb statped">
        <!-- "Format: E-bok" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatEbook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='38']" mode="nlb">
        <!-- "Tilvekstnummer ekstern produksjon" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.external" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='40']" mode="nlb statped">
        <!-- "Tilrettelagt for innlesing" -->
        <!-- Boolean -->
        <dd property="nlbprod:preparedForNarration" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='41']" mode="nlb statped">
        <!-- "DAISY 2.02 ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:daisy202productionComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='42']" mode="nlb statped">
        <!-- "DAISY 2.02 TTS ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:daisy202ttsProductionComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='43']" mode="nlb statped">
        <!-- "Punktskrift ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='44']" mode="nlb statped">
        <!-- "E-bok ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:ebookProductionComplete" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='46']" mode="nlb statped">
        <!-- "Levert innleser" -->
        <!-- Boolean -->
        <dd property="nlbprod:handedOverToNarrator" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='47']" mode="nlb statped">
        <!-- "Tidspunkt for siste endring" -->
        <!-- Integer -->
        <dd property="nlbprod:timeForLastChange" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='48']" mode="nlb statped">
        <!-- "Sist endret av:" -->
        <!-- String -->
        <dd property="nlbprod:lastChangedBy" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='49']" mode="nlb statped">
        <!-- "Produksjoner ID#" -->
        <!-- Integer -->
        <dd property="nlbprod:productionsId" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='51']" mode="nlb statped">
        <!-- "Kommentar katalogisering" -->
        <!-- String -->
        <dd property="nlbprod:commentCatalogization" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='55']" mode="nlb statped">
        <!-- "PDF/grunnlagsfil bestilt" -->
        <!-- Boolean -->
        <dd property="nlbprod:sourceFileOrdered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='56']" mode="nlb statped">
        <!-- "Katalogiseringsdato EPUB" -->
        <!-- Integer -->
        <dd property="nlbprod:catalogizationDateEpub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='58']" mode="nlb">
        <!-- "WIPS ISBN" -->
        <!-- String -->
        <dd property="nlbprod:wipsIsbn" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='60']" mode="nlb">
        <!-- "Til manuell tilrettelegging i NLB" -->
        <!-- Boolean -->
        <dd property="nlbprod:forManualPreparationInNLB" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='61']" mode="nlb statped">
        <!-- "Production approved date" -->
        <!-- Integer -->
        <dd property="nlbprod:productionApprovedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='62']" mode="nlb statped">
        <!-- "Order date" -->
        <!-- Integer -->
        <dd property="nlbprod:orderDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='63']" mode="nlb statped">
        <!-- "Innleser" -->
        <!-- String -->
        <dd property="nlbprod:narrator" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='64']" mode="nlb">
        <!-- "Innlest tid" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='65']" mode="nlb statped">
        <!-- "Levert innleser dato" -->
        <!-- Integer -->
        <dd property="nlbprod:handedOverToNarratorDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='66']" mode="nlb statped">
        <!-- "Student" -->
        <!-- String -->
        <dd property="nlbprod:student" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='67']" mode="nlb statped">
        <!-- "Genre" -->
        <!-- String -->
        <dd property="nlbprod:genre" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='68']" mode="nlb statped">
        <!-- "Ferdig innlest" -->
        <!-- Boolean -->
        <dd property="nlbprod:narrationComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='69']" mode="nlb statped">
        <!-- "Ferdig innlest dato" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationCompletionDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='71']" mode="nlb statped">
        <!-- "Avtalt ferdig innlest dato" -->
        <!-- Integer -->
        <dd property="nlbprod:agreedNarrationCompletionDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='73']" mode="nlb statped">
        <!-- "Tilrettelagt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:preparedDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='74']" mode="nlb statped">
        <!-- "Produsent" -->
        <!-- String -->
        <dd property="nlbprod:producer2" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='77']" mode="nlb">
        <!-- "Format: DAISY 2.02 WIPS" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202wips" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='80']" mode="nlb statped">
        <!-- "Add Record" -->
        <!-- String -->
        <dd property="nlbprod:addRecord" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='81']" mode="nlb statped">
        <!-- "PDF/Grunnlagsfil bestilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:sourceFileOrderedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='82']" mode="nlb statped">
        <!-- "PDF/Grunnlagsfil mottatt/skannet dato" -->
        <!-- Integer -->
        <dd property="nlbprod:sourceFileReceivedOrScannedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='83']" mode="nlb statped">
        <!-- "PDF/Grunnlagsfil format" -->
        <!-- String -->
        <dd property="nlbprod:sourceFileFormat" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='84']" mode="nlb statped">
        <!-- "EPUB/DTBook ordered" -->
        <!-- Boolean -->
        <dd property="nlbprod:epubDTBookOrdered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='85']" mode="nlb statped">
        <!-- "DAISY 2.02 ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202ProductionCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='86']" mode="nlb statped">
        <!-- "DAISY 2.02 TTS ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202ttsProductionCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='87']" mode="nlb statped">
        <!-- "Punktskrift ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='88']" mode="nlb statped">
        <!-- "E-bok ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:ebookProductionCompleteDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='97']" mode="nlb">
        <!-- "Honorar pr ferdig innlest tid" -->
        <!-- Number -->
        <dd property="nlbprod:feeNarratedTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='98']" mode="nlb">
        <!-- "Honorar forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:feePreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='99']" mode="nlb">
        <!-- "Tillegg kveld og helg" -->
        <!-- Number -->
        <dd property="nlbprod:additionalFeeNightAndWeekend" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='103']" mode="nlb">
        <!-- "Innlest tid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:narratedTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='116']" mode="nlb">
        <!-- "Forberedelsestid" -->
        <!-- Integer -->
        <dd property="nlbprod:preparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='117']" mode="nlb">
        <!-- "Kvelds- og helgetillegg" -->
        <!-- Integer -->
        <dd property="nlbprod:additionalNightAndWeekend" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='119']" mode="nlb">
        <!-- "Forberedelsestid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:preparationTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='120']" mode="nlb">
        <!-- "Kvelds- og helgetillegg i timer" -->
        <!-- Number -->
        <dd property="nlbprod:nightAndWeekendInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='122']" mode="nlb">
        <!-- "Sum honorar" -->
        <!-- Number -->
        <dd property="nlbprod:sumFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='131']" mode="nlb">
        <!-- "Annet arbeid for NLB" -->
        <!-- Integer -->
        <dd property="nlbprod:otherWorkForNLB" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='137']" mode="nlb">
        <!-- "Ferdig honorert" -->
        <!-- Boolean -->
        <dd property="nlbprod:feeComplete" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='138']" mode="nlb">
        <!-- "Ferdig honorert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:feeCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='139']" mode="nlb">
        <!-- "Annet arbeid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:otherWorkInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='141']" mode="nlb">
        <!-- "Forskudd" -->
        <!-- Number -->
        <dd property="nlbprod:advancePayment" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='142']" mode="nlb">
        <!-- "Total sum honorar" -->
        <!-- Number -->
        <dd property="nlbprod:totalSumFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='143']" mode="nlb">
        <!-- "Dato for forskuddsbetaling" -->
        <!-- Integer -->
        <dd property="nlbprod:advancePaymentDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='145']" mode="nlb">
        <!-- "Honorar annet arbeid" -->
        <!-- Number -->
        <dd property="nlbprod:feeOtherWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='146']" mode="nlb statped">
        <!-- "DAISY 2.02 klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:daisy202readyForLoan" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='147']" mode="nlb statped">
        <!-- "DAISY 2.02 klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202readyForLoanDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='148']" mode="nlb statped">
        <!-- "Kommentar innlesing" -->
        <!-- String -->
        <dd property="nlbprod:narrationComment" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='149']" mode="nlb statped">
        <!-- "Punktskrift klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='150']" mode="nlb statped">
        <!-- "Punktskrift klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='151']" mode="nlb statped">
        <!-- "E-bok klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:ebookReadyForLoan" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='152']" mode="nlb statped">
        <!-- "E-bok klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:EBOOKReadyForLoanDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='153']" mode="nlb">
        <!-- "Bestillingsskjema ekstern produksjon" -->
        <!-- String -->
        <dd property="nlbprod:orderFormExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='154']" mode="nlb statped">
        <!-- "DTBook sendt i retur" -->
        <!-- Boolean -->
        <dd property="nlbprod:dtbookReturned" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='155']" mode="nlb statped">
        <!-- "DTBook sendt i retur dato" -->
        <!-- Integer -->
        <dd property="nlbprod:dtbookReturnedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='156']" mode="nlb">
        <!-- "DAISY 2.02 Skjønnlitteratur forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202ExpectedCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='157']" mode="nlb statped">
        <!-- "DAISY 2.02 Studielitteratur forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:daisy202studentExpectedCompleteDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='158']" mode="nlb statped">
        <!-- "Punktskrift forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleExpectedCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='159']" mode="nlb">
        <!-- "E-bok forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:ebookProductionExpectedCompleteDate" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='160']" mode="nlb">
        <!-- "Ekstern produksjon forventet ferdigstilt dato" -->
        <!-- Integer -->
        <dd property="nlbprod:externalProductionExpectedCompleteDate" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='161']" mode="nlb statped">
        <!-- "Due date for production" -->
        <!-- Integer -->
        <dd property="nlbprod:dueDateForProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='163']" mode="nlb statped">
        <!-- "Editing instructions" -->
        <!-- String -->
        <dd property="nlbprod:editingInstructions" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='164']" mode="nlb statped">
        <!-- "Oversetter" -->
        <!-- String -->
        <dd property="nlbprod:translator" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='165']" mode="nlb statped">
        <!-- "Språk" -->
        <!-- String -->
        <dd property="nlbprod:language" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='167']" mode="nlb statped">
        <!-- "Delivery Control" -->
        <!-- String -->
        <dd property="nlbprod:deliveryControl" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='170']" mode="nlb statped">
        <!-- "Kategori" -->
        <!-- String -->
        <dd property="nlbprod:category" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='171']" mode="nlb statped">
        <!-- "Format: Noter" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatNotes" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='175']" mode="nlb statped">
        <!-- "Kommentar etterarbeid" -->
        <!-- String -->
        <dd property="nlbprod:commentPostProduction" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='176']" mode="nlb statped">
        <!-- "Spilletid DAISY 2.02" -->
        <!-- Integer -->
        <dd property="nlbprod:playtimeDaisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='177']" mode="nlb statped">
        <!-- "Spilletid DAISY 2.02 TTS" -->
        <!-- Integer -->
        <dd property="nlbprod:playtimeDaisy202tts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='178']" mode="nlb">
        <!-- "Format: Punktklubb" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatBrailleClub" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='180']" mode="nlb">
        <!-- "Ikke til honorering" -->
        <!-- Boolean -->
        <dd property="nlbprod:notForFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='184']" mode="nlb">
        <!-- "Ekstra forberedelsestid" -->
        <!-- Integer -->
        <dd property="nlbprod:extraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='185']" mode="nlb">
        <!-- "Ekstra forberedelsestid i timer" -->
        <!-- Number -->
        <dd property="nlbprod:extraPreparationTimeInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='186']" mode="nlb">
        <!-- "Honorar ekstra forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:feeExtraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='262']" mode="nlb">
        <!-- "Generer fakturagrunnlag" -->
        <!-- Boolean -->
        <dd property="nlbprod:generateFee" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='268']" mode="nlb statped">
        <!-- "Åpen linjeavstand" -->
        <!-- Boolean -->
        <dd property="nlbprod:openLinespacing" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='269']" mode="nlb statped">
        <!-- "Punktsider" -->
        <!-- String -->
        <dd property="dc:format.extent.pages" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='270']" mode="nlb statped">
        <!-- "Hefter" -->
        <!-- String -->
        <dd property="dc:format.extent.volumes" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='279']" mode="nlb">
        <!-- "Sats ferdig innlest tid" -->
        <!-- Number -->
        <dd property="nlbprod:rateNarrationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='280']" mode="nlb">
        <!-- "Sats forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:ratePreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='281']" mode="nlb">
        <!-- "Sats ekstra forberedelsestid" -->
        <!-- Number -->
        <dd property="nlbprod:rateExtraPreparationTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='282']" mode="nlb">
        <!-- "Sats tillegg" -->
        <!-- Number -->
        <dd property="nlbprod:rateAdditionalWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='285']" mode="nlb">
        <!-- "Sats annet arbeid" -->
        <!-- Number -->
        <dd property="nlbprod:rateOtherWork" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='286']" mode="nlb">
        <!-- "Honorarmodell" -->
        <!-- String -->
        <dd property="nlbprod:feeModel" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='304']" mode="nlb">
        <!-- "Generer kvittering" -->
        <!-- Boolean -->
        <dd property="nlbprod:generateReceipt" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='308']" mode="nlb">
        <!-- "Ansatt nr." -->
        <!-- Number -->
        <dd property="nlbprod:employeeNumber" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='309']" mode="nlb">
        <!-- "Konto" -->
        <!-- String -->
        <dd property="nlbprod:account" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='310']" mode="nlb">
        <!-- "Kostnadssted" -->
        <!-- Number -->
        <dd property="nlbprod:costLocation" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='311']" mode="nlb statped">
        <!-- "Overstyring" -->
        <!-- Number -->
        <dd property="nlbprod:overriding" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='312']" mode="nlb">
        <!-- "Lønnart" -->
        <!-- Number -->
        <dd property="nlbprod:paymentType" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='314']" mode="nlb statped">
        <!-- "Signatur etterarbeid DAISY 2.02" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionDaisy202" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='315']" mode="nlb statped">
        <!-- "Signatur etterarbeid DAISY 2.02 TTS" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionDaisy202tts" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='316']" mode="nlb statped">
        <!-- "Signatur etterarbeid punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionBraille" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='317']" mode="nlb statped">
        <!-- "Signatur etterarbeid E-bok" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionEbook" _type-id="ebook">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='318']" mode="nlb statped">
        <!-- "Enkeltsidig trykk" -->
        <!-- Boolean -->
        <dd property="nlbprod:singlePagePrint" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='319']" mode="nlb">
        <!-- "Punktklubb ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleClubProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='320']" mode="nlb">
        <!-- "Punktklubb ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleClubProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='321']" mode="nlb statped">
        <!-- "Signatur etterarbeid punktklubb" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionBrailleClub" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='323']" mode="nlb statped">
        <!-- "Signatur tilrettelegging" -->
        <!-- String -->
        <dd property="nlbprod:signaturePreparation" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='324']" mode="nlb statped">
        <!-- "Signatur DAISY 2.02 klargjort for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureDaisy202readyForLoan" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='325']" mode="nlb statped">
        <!-- "Signatur E-bok klargjort for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureEbookReadyForLoan" _type-id="ebook">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='326']" mode="nlb statped">
        <!-- "Signatur punktskrift klargjort for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureBrailleReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='327']" mode="nlb">
        <!-- "Punktklubb klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:brailleClubReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='328']" mode="nlb">
        <!-- "Punktklubb klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:brailleClubReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='329']" mode="nlb">
        <!-- "Signatur punktklubb klargjort for utån" -->
        <!-- String -->
        <dd property="nlbprod:signatureBrailleClubReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='330']" mode="nlb statped">
        <!-- "Priskategori" -->
        <!-- String -->
        <dd property="nlbprod:priceCategory" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='342']" mode="nlb statped">
        <!-- "E-post forlagskontakt" -->
        <!-- String -->
        <dd property="nlbprod:emailPublisherContact" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='343']" mode="nlb statped">
        <!-- "E-post student" -->
        <!-- String -->
        <dd property="nlbprod:emailStudent" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='344']" mode="nlb statped">
        <!-- "Signatur DTBook bestilt" -->
        <!-- String -->
        <dd property="nlbprod:signatureDTBookOrdered" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='345']" mode="nlb">
        <!-- "Format: DAISY 2.02 ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatDaisy202externalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='346']" mode="nlb">
        <!-- "Format: E-bok ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatEbookExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='347']" mode="nlb">
        <!-- "Format: Audio CD WAV ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatAudioCDWAVExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='348']" mode="nlb">
        <!-- "Format: Audio CD MP3 ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatAudioCDMP3ExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='349']" mode="nlb">
        <!-- "Format: Annet format ekstern produksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatOtherExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='350']" mode="nlb">
        <!-- "Kommentar ekstern produksjon" -->
        <!-- String -->
        <dd property="nlbprod:commentExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='351']" mode="nlb">
        <!-- "Ekstern produksjon ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:externalProductionProductionComplete" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='352']" mode="nlb">
        <!-- "Ekstern produksjon ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:externalProductionProductionCompleteDate" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='353']" mode="nlb statped">
        <!-- "Signatur etterarbeid ekstern produksjon" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionExternalProduction" _type-id="external">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='354']" mode="nlb">
        <!-- "Spilletid ekstern produksjon" -->
        <!-- Integer -->
        <dd property="nlbprod:playtimeExternalProduction" _type-id="external">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='357']" mode="nlb">
        <!-- "Honorering av flere innlesere" -->
        <!-- String -->
        <dd property="nlbprod:feeForMultipleNarrators" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='360']" mode="nlb statped">
        <!-- "Signatur levert innleser" -->
        <!-- String -->
        <dd property="nlbprod:signatureDeliveredToNarrator" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='362']" mode="nlb">
        <!-- "Duplikat" -->
        <!-- Boolean -->
        <dd property="nlbprod:duplicate" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='366']" mode="nlb statped">
        <!-- "Til delproduksjon punktskrift" -->
        <!-- Boolean -->
        <dd property="nlbprod:partialBrailleProduction" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='367']" mode="nlb statped">
        <!-- "Format: Punktskrift delproduksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatBraillePartialProduction" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='368']" mode="nlb statped">
        <!-- "Format: Taktil trykk" -->
        <!-- Boolean -->
        <dd property="nlbprod:formatTactilePrint" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='370']" mode="nlb statped">
        <!-- "Kommentar punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:commentBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='371']" mode="nlb statped">
        <!-- "Taktilt trykk klar for utlån" -->
        <!-- Boolean -->
        <dd property="nlbprod:tactilePrintReadyForLoan" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='372']" mode="nlb statped">
        <!-- "Taktilt trykk klar for utlån dato" -->
        <!-- Integer -->
        <dd property="nlbprod:tactilePrintReadyForLoanDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='374']" mode="nlb statped">
        <!-- "Taktilt trykk ferdig produsert" -->
        <!-- Boolean -->
        <dd property="nlbprod:tactilePrintProductionComplete" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='375']" mode="nlb statped">
        <!-- "Taktilt trykk ferdig produsert dato" -->
        <!-- Integer -->
        <dd property="nlbprod:tactilePrintProductionCompleteDate" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='377']" mode="nlb statped">
        <!-- "Signatur taktilt trykk ferdig produsert" -->
        <!-- String -->
        <dd property="nlbprod:signatureTactilePrintProductionComplete" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='378']" mode="nlb statped">
        <!-- "Signatur taktilt trykk klar for utlån" -->
        <!-- String -->
        <dd property="nlbprod:signatureTactilePrintReadyForLoan" _type-id="braille">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='379']" mode="nlb">
        <!-- "Venting pga. teknisk feil" -->
        <!-- Integer -->
        <dd property="nlbprod:waitingBecauseOfTechnicalProblems" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='380']" mode="nlb">
        <!-- "I studio med produsent" -->
        <!-- Integer -->
        <dd property="nlbprod:inStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='381']" mode="nlb">
        <!-- "Sats ventetid" -->
        <!-- Number -->
        <dd property="nlbprod:rateWaitingTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='382']" mode="nlb">
        <!-- "Sats i studio med produsent" -->
        <!-- Number -->
        <dd property="nlbprod:rateInStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='383']" mode="nlb">
        <!-- "Venting pga teknisk feil i timer" -->
        <!-- Number -->
        <dd property="nlbprod:waitingBecauseOfTechnicalProblemsInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='384']" mode="nlb">
        <!-- "I studio med produsent i timer" -->
        <!-- Number -->
        <dd property="nlbprod:inStudioWithProducerInHours" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='385']" mode="nlb">
        <!-- "Kompensasjon ventetid" -->
        <!-- Number -->
        <dd property="nlbprod:compensationWaitingTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='386']" mode="nlb">
        <!-- "Kompensasjon i studio med produsent" -->
        <!-- Number -->
        <dd property="nlbprod:compensationInStudioWithProducer" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='387']" mode="nlb statped">
        <!-- "Source file" -->
        <!-- String -->
        <dd property="nlbprod:sourceFile" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='388']" mode="nlb statped">
        <!-- "Estimated book category" -->
        <!-- String -->
        <dd property="nlbprod:estimatedBookCategory" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='389']" mode="nlb statped">
        <!-- "Book category" -->
        <!-- String -->
        <dd property="nlbprod:bookCategory" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='390']" mode="nlb statped">
        <!-- "Number of pages" -->
        <!-- Integer -->
        <dd property="nlbprod:numberOfPages2" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='392']" mode="nlb statped">
        <!-- "Upload EPUB 3 file" -->
        <!-- String -->
        <dd property="nlbprod:uploadEpub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='393']" mode="nlb statped">
        <!-- "Production delivered" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionDelivered" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='395']" mode="nlb statped">
        <!-- "Production delivery date" -->
        <!-- Integer -->
        <dd property="nlbprod:productionDeliveryDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='396']" mode="nlb statped">
        <!-- "Agency" -->
        <!-- String -->
        <dd property="schema:library" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='397']" mode="nlb statped">
        <!-- "Production number-UID" -->
        <!-- Number -->
        <dd property="nlbprod:productionNumberUID" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='398']" mode="nlb statped">
        <!-- "Leave a message" -->
        <!-- Boolean -->
        <dd property="nlbprod:leaveAMessage" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='399']" mode="nlb statped">
        <!-- "Production Questions and Notes" -->
        <!-- String -->
        <dd property="nlbprod:productionQuestionsAndNotes" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='402']" mode="nlb statped">
        <!-- "Kommentar bestilling" -->
        <!-- String -->
        <dd property="nlbprod:commentOrder" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='403']" mode="nlb statped">
        <!-- "Purchase order ID" -->
        <!-- String -->
        <dd property="nlbprod:purchaseOrderId" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='405']" mode="nlb statped">
        <!-- "ASCIIMath" -->
        <!-- Boolean -->
        <dd property="nlbprod:asciimath" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='406']" mode="nlb statped">
        <!-- "Source file format" -->
        <!-- String -->
        <dd property="nlbprod:sourceFileFormat2" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='407']" mode="nlb statped">
        <!-- "Alternate source file URL" -->
        <!-- String -->
        <dd property="nlbprod:alternateSourceFileURL" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='408']" mode="nlb statped">
        <!-- "Exercises and answers" -->
        <!-- Boolean -->
        <dd property="nlbprod:exercisesAndAnswers" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='409']" mode="nlb statped">
        <!-- "Inline text styling" -->
        <!-- Boolean -->
        <dd property="nlbprod:inlineTextStyling" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='410']" mode="nlb statped">
        <!-- "Extraction of text content in images" -->
        <!-- Boolean -->
        <dd property="nlbprod:extractionOfTextContentInImages" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='413']" mode="nlb statped">
        <!-- "Production returned" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionReturned" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='414']" mode="nlb statped">
        <!-- "Production return date" -->
        <!-- Integer -->
        <dd property="nlbprod:productionReturnDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='415']" mode="nlb statped">
        <!-- "Kommentar EPUB-bestilling" -->
        <!-- String -->
        <dd property="nlbprod:commentEpubOrder" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='416']" mode="nlb statped">
        <!-- "Production downloaded" -->
        <!-- Boolean -->
        <dd property="nlbprod:productionDownloaded" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='417']" mode="nlb statped">
        <!-- "Downloaded date" -->
        <!-- Integer -->
        <dd property="nlbprod:downloadedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='418']" mode="nlb statped">
        <!-- "Signatur for nedlasting" -->
        <!-- String -->
        <dd property="nlbprod:signatureForDownload" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='419']" mode="nlb statped">
        <!-- "Pages" -->
        <!-- Integer -->
        <dd property="nlbprod:pages" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='420']" mode="nlb statped">
        <!-- "Title" -->
        <!-- String -->
        <dd property="nlbprod:title2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='421']" mode="nlb statped">
        <!-- "Author" -->
        <!-- String -->
        <dd property="nlbprod:author2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='422']" mode="nlb statped">
        <!-- "Contributor" -->
        <!-- String -->
        <dd property="nlbprod:contributor" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='423']" mode="nlb statped">
        <!-- "Language" -->
        <!-- String -->
        <dd property="nlbprod:language2" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='426']" mode="nlb statped">
        <!-- "Signatur godkjent produksjon" -->
        <!-- String -->
        <dd property="nlbprod:signatureApprovedProduction" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='427']" mode="nlb statped">
        <!-- "Signatur returnert produksjon" -->
        <!-- String -->
        <dd property="nlbprod:signatureReturnedProduction" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='428']" mode="nlb statped">
        <!-- "Validation log file" -->
        <!-- String -->
        <dd property="nlbprod:validationLogFile" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='429']" mode="nlb statped">
        <!-- "Original ISSN" -->
        <!-- String -->
        <dd property="nlbprod:originalISSN" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='430']" mode="nlb statped">
        <!-- "Hefte nr" -->
        <!-- String -->
        <dd property="nlbprod:volumeNumber" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='431']" mode="nlb statped">
        <!-- "<dc:source>urn:isbn:" -->
        <!-- String -->
        <dd property="nlbprod:dcSourceUrnIsbn" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='432']" mode="nlb">
        <!-- "Hasteproduksjon" -->
        <!-- Boolean -->
        <dd property="nlbprod:urgentProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='434']" mode="nlb">
        <!-- "Kvelds- og helgetillegg prosent av total tid" -->
        <!-- Number -->
        <dd property="nlbprod:nightAndWeekendPercentageOfTotalTime" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='436']" mode="nlb">
        <!-- "Signatur honorering" -->
        <!-- String -->
        <dd property="nlbprod:signatureFee" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='437']" mode="nlb statped">
        <!-- "Signatur registrering" -->
        <!-- String -->
        <dd property="nlbprod:signatureRegistration" _type-id="creativeWork">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='438']" mode="nlb statped">
        <!-- "Ny registrering" -->
        <!-- Boolean -->
        <dd property="nlbprod:newRegistration" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='439']" mode="nlb">
        <!-- "Innleser_copy" -->
        <!-- String -->
        <dd property="nlbprod:narratorCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='440']" mode="nlb">
        <!-- "Ansatt nr._copy" -->
        <!-- Number -->
        <dd property="nlbprod:employeeNumberCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='442']" mode="nlb statped">
        <!-- "Avtalt ferdig innlest dato_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:agreedNarrationCompletionDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='443']" mode="nlb">
        <!-- "Levert innleser_copy" -->
        <!-- Boolean -->
        <dd property="nlbprod:handedOverToNarratorCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='444']" mode="nlb">
        <!-- "Levert innleser dato_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:handedOverToNarratorDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='445']" mode="nlb">
        <!-- "Generer kvittering_copy" -->
        <!-- Boolean -->
        <dd property="nlbprod:generateReceiptCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='446']" mode="nlb">
        <!-- "Produsent_copy" -->
        <!-- String -->
        <dd property="nlbprod:producerCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='447']" mode="nlb">
        <!-- "Ferdig innlest_copy" -->
        <!-- Boolean -->
        <dd property="nlbprod:narrationCompleteCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='448']" mode="nlb">
        <!-- "Ferdig innlest dato_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationCompleteDateCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='449']" mode="nlb">
        <!-- "Honorarmodell_copy" -->
        <!-- String -->
        <dd property="nlbprod:feeModelCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='450']" mode="nlb">
        <!-- "Innlest tid_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:narrationTimeCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='451']" mode="nlb">
        <!-- "Innlest tid i timer_copy" -->
        <!-- Number -->
        <dd property="nlbprod:narrationTimeInHoursCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='452']" mode="nlb">
        <!-- "Sats annet arbeid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:rateOtherWorkCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='453']" mode="nlb">
        <!-- "Sats ekstra forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:rateExtraPreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='454']" mode="nlb">
        <!-- "Sats ferdig innlest tid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:rateNarrationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='455']" mode="nlb">
        <!-- "Sats forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:ratePreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='456']" mode="nlb">
        <!-- "Honorar annet arbeid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feeOtherWorkCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='457']" mode="nlb">
        <!-- "Honorar ekstra forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feeExtraPreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='458']" mode="nlb">
        <!-- "Honorar forberedelsestid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feePreparationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='459']" mode="nlb">
        <!-- "Honorar pr ferdig innlest tid_copy" -->
        <!-- Number -->
        <dd property="nlbprod:feeNarrationCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='461']" mode="nlb">
        <!-- "I studio med produsent_copy" -->
        <!-- Integer -->
        <dd property="nlbprod:inStudioWithProducerCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='462']" mode="nlb">
        <!-- "Sum honorar_copy" -->
        <!-- Number -->
        <dd property="nlbprod:sumFeeCopy" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='463']" mode="nlb statped">
        <!-- "Etterarbeid startet" -->
        <!-- Boolean -->
        <dd property="nlbprod:postProductionStarted" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='464']" mode="nlb statped">
        <!-- "Etterarbeid startet dato" -->
        <!-- Integer -->
        <dd property="nlbprod:postProductionStartedDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='465']" mode="nlb statped">
        <!-- "Signatur for påbegynt etterarbeid" -->
        <!-- String -->
        <dd property="nlbprod:signaturePostProductionStarted" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='466']" mode="nlb">
        <!-- "Honorarkrav behandlet" -->
        <!-- Boolean -->
        <dd property="nlbprod:feeClaimHandled" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='467']" mode="nlb">
        <!-- "Honorarkrav behandlet dato" -->
        <!-- Integer -->
        <dd property="nlbprod:feeClaimHandledDate" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='468']" mode="nlb statped">
        <!-- "Signatur honorarkrav behandlet" -->
        <!-- String -->
        <dd property="nlbprod:signatureFeeClaimHandled" _type-id="audio">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='469']" mode="nlb statped">
        <!-- "EPUB3" -->
        <!-- String -->
        <dd property="nlbprod:epub3" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='470']" mode="nlb statped">
        <!-- "E-bok" -->
        <!-- String -->
        <dd property="nlbprod:ebook" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='471']" mode="nlb statped">
        <!-- "DAISY 2.02" -->
        <!-- String -->
        <dd property="nlbprod:daisy202" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='472']" mode="nlb statped">
        <!-- "Punktskrift" -->
        <!-- String -->
        <dd property="nlbprod:braille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='473']" mode="nlb">
        <!-- "www.bokbasen.no" -->
        <!-- Boolean -->
        <dd property="nlbprod:bokbasen" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='474']" mode="nlb statped">
        <!-- "Statusikon" -->
        <!-- String -->
        <dd property="nlbprod:statusIcon" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='475']" mode="nlb statped">
        <!-- "Status" -->
        <!-- String -->
        <dd property="nlbprod:status" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='476']" mode="nlb statped">
        <!-- "Pris per side" -->
        <!-- Number -->
        <dd property="nlbprod:pricePerPage" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='477']" mode="nlb statped">
        <!-- "Total pris for EPUB-produksjon ()" -->
        <!-- Number -->
        <dd property="nlbprod:totalPriceForEpubProduction" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='479']" mode="nlb statped">
        <!-- "<dc:creator>" -->
        <!-- String -->
        <dd property="nlbprod:dcCreator" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='480']" mode="nlb statped">
        <!-- "Multivolum antall CDer" -->
        <!-- Number -->
        <dd property="nlbprod:multivolumeNumberOfCDs" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='481']" mode="nlb statped">
        <!-- "Lydbok med tekst" -->
        <!-- Boolean -->
        <dd property="nlbprod:narratedFulltext" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='482']" mode="nlb statped">
        <!-- "OCR-kontroll utført" -->
        <!-- Boolean -->
        <dd property="nlbprod:ocrChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='483']" mode="nlb statped">
        <!-- "Metadata kontrollert" -->
        <!-- Boolean -->
        <dd property="nlbprod:metadataChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='484']" mode="nlb statped">
        <!-- "Struktur kontrollert" -->
        <!-- Boolean -->
        <dd property="nlbprod:structureChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='485']" mode="nlb statped">
        <!-- "Editing instructions kontrollert" -->
        <!-- Boolean -->
        <dd property="nlbprod:editingInstructionsChecked" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='488']" mode="nlb statped">
        <!-- "Dato kontroll påbegynt" -->
        <!-- Integer -->
        <dd property="nlbprod:controlStartedDate" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='487']" mode="nlb statped">
        <!-- "Kontroll påbegynt" -->
        <!-- Boolean -->
        <dd property="nlbprod:controlStarted" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='494']" mode="nlb">
        <!-- "PDF fra NB" -->
        <!-- Boolean -->
        <dd property="nlbprod:pdfFromNb" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='495']" mode="nlb statped">
        <!-- "Konverter EPUB til DTBook for TTS" -->
        <!-- Boolean -->
        <dd property="nlbprod:triggerTts" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='496']" mode="nlb statped">
        <!-- "Konverter EPUB til DTBook for Punktskrift" -->
        <!-- Boolean -->
        <dd property="nlbprod:triggerBraille" _type-id="braille">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='497']" mode="nlb statped">
        <!-- "Konverter EPUB til DTBook for HTML" -->
        <!-- Boolean -->
        <dd property="nlbprod:triggerHtml" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='489']" mode="nlb statped">
        <!-- "Signatur kontroll påbegynt" -->
        <!-- String -->
        <dd property="nlbprod:signatureControlStarted" _type-id="epub">
            <xsl:variable name="id" select="normalize-space(.)"/>
            <xsl:value-of select="($lusers, ancestor::qdbapi/table/lusers)[1]/luser[@id=$id]/text()"/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='498']" mode="nlb statped">
        <!-- "Start EPUB konvertering" -->
        <!-- Boolean -->
        <dd property="nlbprod:triggerEpub" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='499']" mode="nlb statped">
        <!-- "MathML" -->
        <!-- Boolean -->
        <dd property="nlbprod:containsMathML" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='503']" mode="statped">
        <!--- "Tilvekstnummer DAISY 2.02 TTS" -->
        <!-- Integer -->
        
        <!--
            Hvis dette er en talesyntesebok, bruk 'nlbprod:identifier.daisy202', ellers 'nlbprod:identifier.daisy202.tts'.
            Dette er for å sikre at det er riktig boknummer som brukes (ikke TTS-boknummer på innleste bøker og omvendt).
        -->
        <xsl:variable name="formatDaisy202Narrated" select="../f[@id='26']/text() = '1'" as="xs:boolean"/>
        <xsl:variable name="formatDaisy202Tts" select="../f[@id='27']/text() = '1'" as="xs:boolean"/>
        
        <dd property="nlbprod:identifier.daisy202{if (not($formatDaisy202Narrated) and $formatDaisy202Tts) then '' else '.tts'}" _type-id="audio">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='502']" mode="nlb statped">
        <!-- "Upload editing instructions" -->
        <!-- String -->
        <dd property="nlbprod:uploadEditingInstructions" _type-id="epub">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='504']" mode="statped">
        <!--- "Tilvekstnummer E-bok Word" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.ebook.word" _type-id="ebook">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='505']" mode="statped">
        <!--- "Tilvekstnummer format X" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.reserved" _type-id="">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='506']" mode="statped">
        <!--- "Tilvekstnummer format XX" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.reserved" _type-id="">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='507']" mode="statped">
        <!--- "Tilvekstnummer format XXX" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.reserved" _type-id="">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='508']" mode="statped">
        <!--- "Tilvekstnummer format XXXX" -->
        <!-- Integer -->
        <dd property="nlbprod:identifier.reserved" _type-id="">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>
    
    <xsl:template match="f[@id='record_id']" mode="nlb statped">
        <!-- Integer -->
        <dd property="nlbprod:record_id" _type-id="creativeWork">
            <xsl:value-of select="."/>
        </dd>
    </xsl:template>

</xsl:stylesheet>
