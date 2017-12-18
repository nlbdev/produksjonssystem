<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:SRU="http://www.loc.gov/zing/sru/"
                xmlns:normarc="info:lc/xmlns/marcxchange-v1"
                xmlns:DIAG="http://www.loc.gov/zing/sru/diagnostics/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:schema="http://schema.org/"
                xmlns:frbr="http://purl.org/vocab/frbr/core#"
                xmlns:nlbbib="http://www.nlb.no/bibliographic"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:import href="marcxchange-to-opf/marcxchange-to-opf.xsl"/>
    <xsl:variable name="nested" select="true()"/>
    
    <xsl:output indent="yes" method="xhtml"/>
    
    <xsl:param name="rdf-xml-path" as="xs:string"/>
    
    <xsl:template match="/SRU:searchRetrieveResponse">
        <xsl:variable name="metadata" as="element()?">
            <xsl:next-match/>
        </xsl:variable>
        
        <xsl:variable name="resource-creativeWork" select="($metadata/*[@name='isbn.original' and normalize-space(@content)]/concat('urn:isbn:', replace(normalize-space(@content),'[^\d]','')), concat('creativeWork_',generate-id()))[1]"/>
        <xsl:variable name="resource-book" select="($metadata/dc:identifier[normalize-space(@content)]/concat('http://websok.nlb.no/cgi-bin/websok?tnr=', normalize-space(@content)), concat('book_',generate-id()))[1]"/>
        <xsl:variable name="resource-original" select="concat('original_',generate-id())"/>
        
        <html xmlns:nlb="http://nlb.no/" nlb:source="quickbase-record">
            <head>
                <title><xsl:value-of select="($metadata/dc:title/@content, 'Bibliofil')[1]"/></title>
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
                <xsl:choose>
                    <xsl:when test="not($metadata)">
                        <p>Bibliofil-metadata mangler.</p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:attribute name="{if (matches($resource-creativeWork,'^(http|urn)')) then 'about' else 'id'}" select="$resource-creativeWork"/>
                        <h1><xsl:value-of select="$metadata/dc:title/@content"/></h1>
                        
                        <xsl:call-template name="list-metadata-rdfa">
                            <xsl:with-param name="metadata" select="$metadata"/>
                            <xsl:with-param name="type" select="'creativeWork'"/>
                        </xsl:call-template>
                        
                        <section vocab="http://schema.org/" typeof="Book" id="{$resource-original}">
                            <link property="exampleOfWork" href="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                            <h1>Original</h1>
                            
                            <xsl:call-template name="list-metadata-rdfa">
                                <xsl:with-param name="metadata" select="$metadata"/>
                                <xsl:with-param name="type" select="'original'"/>
                            </xsl:call-template>
                        </section>
                        
                        <section vocab="http://schema.org/" typeof="Book" id="{$resource-original}">
                            <xsl:attribute name="{if (matches($resource-book,'^(http|urn)')) then 'about' else 'id'}" select="$resource-book"/>
                            <link property="exampleOfWork" href="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                            <link property="frbr:translationOf" href="#{$resource-original}"/>
                            
                            <h1><xsl:value-of select="$metadata/dc:format/@content"/></h1>
                            
                            <xsl:call-template name="list-metadata-rdfa">
                                <xsl:with-param name="metadata" select="$metadata"/>
                                <xsl:with-param name="type" select="'book'"/>
                            </xsl:call-template>
                        </section>
                    </xsl:otherwise>
                </xsl:choose>
            </body>
        </html>
        
        <xsl:if test="$rdf-xml-path">
            <xsl:result-document href="{$rdf-xml-path}" indent="yes">
                <rdf:RDF>
                    <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
                    <xsl:namespace name="schema" select="'http://schema.org/'"/>
                    <xsl:namespace name="frbr" select="'http://purl.org/vocab/frbr/core#'"/>
                    <xsl:namespace name="nlbbib" select="'http://www.nlb.no/bibliographic'"/>
                    <xsl:if test="$metadata">
                        <rdf:Description>
                            <xsl:attribute name="rdf:{if (matches($resource-creativeWork,'^(http|urn)')) then 'about' else 'ID'}" select="$resource-creativeWork"/>
                            <rdf:type rdf:resource="http://schema.org/CreativeWork"/>
                            <xsl:call-template name="list-metadata-rdfxml">
                                <xsl:with-param name="metadata" select="$metadata"/>
                                <xsl:with-param name="type" select="'creativeWork'"/>
                            </xsl:call-template>
                        </rdf:Description>
                        <rdf:Description rdf:ID="{$resource-original}">
                            <rdf:type rdf:resource="http://schema.org/Book"/>
                            <schema:exampleOfWork rdf:resource="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                            <xsl:call-template name="list-metadata-rdfxml">
                                <xsl:with-param name="metadata" select="$metadata"/>
                                <xsl:with-param name="type" select="'original'"/>
                            </xsl:call-template>
                        </rdf:Description>
                        <rdf:Description>
                            <xsl:attribute name="rdf:{if (matches($resource-book,'^(http|urn)')) then 'about' else 'ID'}" select="$resource-book"/>
                            <rdf:type rdf:resource="http://schema.org/Book"/>
                            <schema:exampleOfWork rdf:resource="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                            <frbr:translationOf rdf:resource="#{$resource-original}"/>
                            <xsl:call-template name="list-metadata-rdfxml">
                                <xsl:with-param name="metadata" select="$metadata"/>
                                <xsl:with-param name="type" select="'book'"/>
                            </xsl:call-template>
                        </rdf:Description>
                    </xsl:if>
                </rdf:RDF>
            </xsl:result-document>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="list-metadata-rdfa" as="element()?">
        <xsl:param name="metadata" as="element()"/>
        <xsl:param name="type" as="xs:string" required="yes"/>
        
        <xsl:variable name="rdfxml" as="element()*">
            <xsl:call-template name="list-metadata-rdfxml">
                <xsl:with-param name="metadata" select="$metadata"/>
                <xsl:with-param name="type" select="$type"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:call-template name="rdfxml-to-rdfa">
            <xsl:with-param name="rdfxml" select="$rdfxml"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="rdfxml-to-rdfa">
        <xsl:param name="rdfxml" as="element()*"/>
        
        <dl>
            <xsl:for-each select="$rdfxml">
                <dt title="{name()}"><xsl:value-of select="name()"/></dt>
                <dd property="{name()}">
                    <xsl:choose>
                        <xsl:when test="count(*)">
                            <p><xsl:value-of select="@schema:name"/></p>
                            <xsl:text> </xsl:text>
                            <xsl:call-template name="rdfxml-to-rdfa">
                                <xsl:with-param name="rdfxml" select="*"/>
                            </xsl:call-template>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="."/>
                        </xsl:otherwise>
                    </xsl:choose>
                </dd>
            </xsl:for-each>
        </dl>
    </xsl:template>
    
    <xsl:template name="list-metadata-rdfxml" as="element()*">
        <xsl:param name="metadata" as="element()"/>
        <xsl:param name="type" as="xs:string" required="yes"/>
        <xsl:param name="nested" as="xs:boolean" select="false()" required="no"/>
        
        <xsl:variable name="creativeWorkProperties" select="('dc:title', 'dc:creator', 'dc:language', 'dc:contributor', 'schema:bookEdition', 'schema:isbn.original',
                                                             'dc:contributor.translator', 'dc:contributor.photographer', 'dc:contributor.illustrator', 'dc:contributor.consultant', 'dc:contributor.secretary', 'dc:contributor.editor',
                                                             'dc:contributor.collaborator', 'dc:contributor.commentator', 'dc:contributor.narrator', 'dc:contributor.director', 'dc:contributor.compiler')"/>
        <xsl:variable name="nlbbibProperties" select="('series.issn','series.position','periodical','periodicity','magazine','newspaper','watermark','external-production','websok.url','websok.type','bibliofil-id','pseudonym')"/>
        
        <xsl:for-each select="$metadata/*">
            <xsl:variable name="name" select="(@name, name())[1]"/>
            <xsl:variable name="name" select="if ($name = $nlbbibProperties) then concat('nlbbib:',$name) else $name"/>
            <xsl:variable name="name" select="if (not(contains($name,':'))) then concat('schema:',$name) else $name"/>
            
            <xsl:variable name="element" as="element()">
                <xsl:element name="{$name}">
                    <xsl:choose>
                        <xsl:when test="count(*)">
                            <xsl:attribute name="schema:name" select="@content"/>
                            <xsl:call-template name="list-metadata-rdfxml">
                                <xsl:with-param name="metadata" select="."/>
                                <xsl:with-param name="type" select="$type"/>
                                <xsl:with-param name="nested" select="true()"/>
                            </xsl:call-template>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@content"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
            </xsl:variable>
            
            <xsl:choose>
                <xsl:when test="$nested">
                    <xsl:sequence select="$element"/>
                </xsl:when>
                <xsl:when test="$type = 'creativeWork'">
                    <xsl:if test="$name = $creativeWorkProperties">
                        <xsl:choose>
                            <xsl:when test="$name = 'schema:isbn.original'">
                                <xsl:element name="schema:isbn">
                                    <xsl:copy-of select="$element/(@* | node())"/>
                                </xsl:element>
                                <xsl:element name="dc:source">
                                    <xsl:copy-of select="concat('urn:isbn:',replace($element/text()[1],'[^\d]',''))"/>
                                </xsl:element>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:sequence select="$element"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>
                </xsl:when>
                <xsl:when test="$type = 'original'">
                    <xsl:if test="ends-with($name, '.original') and not($name = 'isbn.original')">
                        <xsl:element name="{replace($name,'.original$','')}">
                            <xsl:copy-of select="$element/node()"/>
                        </xsl:element>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if test="not($name = $creativeWorkProperties) and not(ends-with($name, '.original'))">
                        <xsl:sequence select="$element"/>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
</xsl:stylesheet>