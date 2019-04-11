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
                xmlns:owl="http://www.w3.org/2002/07/owl#"
                xmlns:nlb="http://www.nlb.no/"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <!-- note: assumes input XML is from marcxchange-to-opf.xsl with param nested = true -->
    
    <xsl:variable name="nested" select="true()"/>
    
    <xsl:output indent="yes" method="xhtml"/>
    
    <xsl:param name="rdf-xml-path" as="xs:string?"/>
    <xsl:param name="edition-identifier" select="''" as="xs:string"/>
    
    <xsl:template match="/*">
        <xsl:variable name="metadata" as="element()" select="/*"/>
        
        <xsl:variable name="identifier" select="$metadata/dc:identifier"/>
        
        <xsl:variable name="resource-creativeWork" select="(
                                                                $metadata/*[@name='isbn.original' and matches(@content, '.*\d.*')]/concat('urn:isbn:', replace(@content,'[^\d]','')),
                                                                $metadata/*[@name='issn.original' and matches(@content, '.*\d.*')]/concat('urn:issn:', replace(@content,'[^\d]','')),
                                                                concat('creativeWork_',replace(string(current-time()),'[^\d]',''),'_',generate-id())
                                                            )[1]"/>
        <xsl:variable name="resource-book" select="(
                                                        $metadata/dc:identifier[normalize-space(@content)]/concat('urn:nbn:no-nb_nlb_', normalize-space(@content), $edition-identifier),
                                                        concat('book_',replace(string(current-time()),'[^\d]',''),'_',generate-id())
                                                    )[1]"/>
        
        <xsl:variable name="html" as="element()">
            <html xmlns:nlb="http://nlb.no/" nlb:source="bibliofil-record">
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
                            
                            <section vocab="http://schema.org/" typeof="Book">
                                <xsl:attribute name="{if (matches($resource-book,'^(http|urn)')) then 'about' else 'id'}" select="$resource-book"/>
                                <link property="exampleOfWork" href="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                                <xsl:if test="exists($metadata/*[@name = ('isbn', 'issn')])">
                                    <xsl:variable name="isbn-issn" select="($metadata/*[@name = ('isbn', 'issn')])[1]" as="element()"/>
                                    <link property="owl:sameAs" href="urn:{$isbn-issn/@name}:{replace($isbn-issn/@content,'[^0-9X]','')}"/>
                                </xsl:if>
                                
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
        </xsl:variable>
        
        <xsl:variable name="rdf" as="element()">
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
                        <rdf:Description>
                            <xsl:attribute name="rdf:{if (matches($resource-book,'^(http|urn)')) then 'about' else 'ID'}" select="$resource-book"/>
                            <rdf:type rdf:resource="http://schema.org/Book"/>
                            <schema:exampleOfWork rdf:resource="{if (matches($resource-creativeWork,'^(http|urn)')) then $resource-creativeWork else concat('#',$resource-creativeWork)}"/>
                            <xsl:if test="exists($metadata/*[@name = ('isbn', 'issn')])">
                                <xsl:variable name="isbn-issn" select="($metadata/*[@name = ('isbn', 'issn')])[1]" as="element()"/>
                                <owl:sameAs rdf:resource="urn:{$isbn-issn/@name}:{replace($isbn-issn/@content,'[^0-9X]','')}"/>
                            </xsl:if>
                            <xsl:call-template name="list-metadata-rdfxml">
                                <xsl:with-param name="metadata" select="$metadata"/>
                                <xsl:with-param name="type" select="'book'"/>
                            </xsl:call-template>
                        </rdf:Description>
                    </xsl:if>
                </rdf:RDF>
        </xsl:variable>
        
        <xsl:choose>
            <xsl:when test="$rdf-xml-path">
                <xsl:sequence select="$html"/>
                <xsl:result-document href="{$rdf-xml-path}" indent="yes">
                    <xsl:sequence select="$rdf"/>
                </xsl:result-document>
                
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$rdf"/>
            </xsl:otherwise>
        </xsl:choose>
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
                    <xsl:if test="@nlb:metadata-source">
                        <xsl:attribute name="title" select="@nlb:metadata-source"/>
                    </xsl:if>
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
        
        <xsl:variable name="creativeWorkProperties" select="('dc:title', 'dc:creator', 'dc:language', 'dc:contributor', 'schema:bookEdition', 'dc:subject', 'dc:type.genre',
                                                             'nlbbib:series.issn', 'nlbbib:series.position', 'nlbbib:periodical', 'nlbbib:periodicity', 'nlbbib:magazine', 'nlbbib:newspaper',
                                                             $metadata//*[starts-with(@name,'dc:title.')]/string(@name),
                                                             $metadata//*[starts-with(@name,'dc:contributor.') and not(@name='dc:contributor.narrator')]/string(@name),
                                                             $metadata//*[starts-with(@name,'dc:subject.')]/string(@name))"/>
        <xsl:variable name="nlbbibProperties" select="('series.issn','series.position','periodical','periodicity','magazine','newspaper','watermark','external-production','websok.url','websok.type','bibliofil-id','pseudonym','epub-nr')"/>
        
        <xsl:for-each select="$metadata/*">
            <xsl:variable name="name" select="(@name, name())[1]"/>
            <xsl:variable name="name" select="if ($name = $nlbbibProperties) then concat('nlbbib:',$name) else $name"/>
            <xsl:variable name="name" select="if (not(contains($name,':'))) then concat('schema:',$name) else $name"/>
            
            <xsl:variable name="element" as="element()">
                <xsl:element name="{$name}">
                    <xsl:copy-of select="@nlb:metadata-source"/>
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
                    <xsl:if test="$name = $creativeWorkProperties or ends-with($name, '.original')">
                        <!--
                            Åndsverk fra bibliofil har ikke schema:isbn, kun schema:isbn.original.
                            Dvs. 5xx-bøker katalogiseres ikke med ISBN i *020$a, men om de hadde
                            hatt det så måtte det vært det samme som i *596$f.
                        -->
                        <xsl:choose>
                            <xsl:when test="$name = 'schema:isbn.original'">
                                <xsl:element name="schema:isbn">
                                    <xsl:copy-of select="$element/(@* | node())"/>
                                </xsl:element>
                                <xsl:element name="dc:source">
                                    <xsl:copy-of select="@nlb:metadata-source"/>
                                    <xsl:copy-of select="concat('urn:isbn:',replace($element/text()[1],'[^\d]',''))"/>
                                </xsl:element>
                            </xsl:when>
                            
                            <xsl:when test="$name = 'schema:issn.original'">
                                <xsl:element name="schema:issn">
                                    <xsl:copy-of select="$element/(@* | node())"/>
                                </xsl:element>
                                <xsl:element name="dc:source">
                                    <xsl:copy-of select="@nlb:metadata-source"/>
                                    <xsl:copy-of select="concat('urn:issn:',replace($element/text()[1],'[^\d]',''))"/>
                                </xsl:element>
                            </xsl:when>
                            
                            <xsl:otherwise>
                                <xsl:sequence select="$element"/>
                            </xsl:otherwise>
                        </xsl:choose>
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