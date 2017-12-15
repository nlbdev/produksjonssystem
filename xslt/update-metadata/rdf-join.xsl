<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:param name="metadata-dir" required="yes" as="xs:string"/>
    <xsl:param name="rdf-files" required="yes" as="xs:string"/>
    <xsl:variable name="rdf-file-uris" select="for $r in tokenize($rdf-files,'\s+') return resolve-uri($r, resolve-uri($metadata-dir))" as="xs:string*"/>
    
    <xsl:template name="main">
        <xsl:variable name="result" as="element()">
            <rdf:RDF>
                <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
                <xsl:namespace name="schema" select="'http://schema.org/'"/>
                <xsl:namespace name="nlbprod" select="'http://www.nlb.no/production'"/>
                <xsl:namespace name="frbr" select="'http://purl.org/vocab/frbr/core#'"/>
                <xsl:namespace name="nlbbib" select="'http://www.nlb.no/bibliographic'"/>
                <xsl:variable name="descriptions" select="for $r in $rdf-file-uris return document($r)//rdf:Description"/>
                <xsl:variable name="descriptions" as="element()*">
                    <xsl:for-each select="$descriptions">
                        <xsl:variable name="source" select="replace(base-uri(),'.*/([^/]+)/[^/]*$','$1')"/>
                        <xsl:element name="{name()}">
                            <xsl:copy-of select="@*"/>
                            <xsl:attribute name="_source" select="$source"/>
                            <xsl:copy-of select="node()"/>
                        </xsl:element>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:for-each select="distinct-values($descriptions/@rdf:about[starts-with(.,'urn:')])">
                    <xsl:sort/>
                    <xsl:variable name="about" select="."/>
                    <rdf:Description>
                        <xsl:attribute name="rdf:about" select="$about"/>
                        
                        <xsl:call-template name="merge-properties">
                            <xsl:with-param name="descriptions" select="($descriptions[@rdf:about=$about and @_source='bibliofil'], $descriptions[@rdf:about=$about and @_source='quickbase'], $descriptions[@rdf:about=$about and @_source='epub'])"/>
                        </xsl:call-template>
                    </rdf:Description>
                </xsl:for-each>
                <xsl:for-each select="distinct-values($descriptions/@rdf:about[not(starts-with(.,'urn:'))])">
                    <xsl:sort/>
                    <xsl:variable name="about" select="."/>
                    <rdf:Description>
                        <xsl:attribute name="rdf:about" select="$about"/>
                        
                        <xsl:call-template name="merge-properties">
                            <xsl:with-param name="descriptions" select="($descriptions[@rdf:about=$about and @_source='bibliofil'], $descriptions[@rdf:about=$about and @_source='quickbase'], $descriptions[@rdf:about=$about and @_source='epub'])"/>
                        </xsl:call-template>
                    </rdf:Description>
                </xsl:for-each>
                <xsl:for-each select="distinct-values($descriptions/@rdf:ID)">
                    <xsl:sort/>
                    <xsl:variable name="ID" select="."/>
                    <rdf:Description>
                        <xsl:attribute name="rdf:ID" select="."/>
                        
                        <xsl:call-template name="merge-properties">
                            <xsl:with-param name="descriptions" select="($descriptions[@rdf:ID=$ID and @_source='bibliofil'], $descriptions[@rdf:ID=$ID and @_source='quickbase'], $descriptions[@rdf:ID=$ID and @_source='epub'])"/>
                        </xsl:call-template>
                    </rdf:Description>
                </xsl:for-each>
            </rdf:RDF>
        </xsl:variable>
        
        <!-- move namespaces to root element -->
        <xsl:for-each select="$result">
            <xsl:copy>
                <xsl:copy-of select=".//namespace::*"/>
                <xsl:copy-of select="@* | node()"/>
            </xsl:copy>
        </xsl:for-each>
    </xsl:template>
    
    <!-- Merges in new metadata recursively -->
    <xsl:template name="merge-properties" as="element()*">
        <xsl:param name="properties" select="()" as="element()*"/>
        <xsl:param name="descriptions" required="yes" as="element()*"/>
        
        <xsl:variable name="new" select="if (count($descriptions)) then $descriptions[1] else ()"/>
        <xsl:variable name="remaining" select="if (count($descriptions)) then $descriptions[position() gt 1] else ()"/>
        
        <xsl:message select="concat('descriptions:',count($descriptions))"/>
        <xsl:message select="concat('new:',count($new))"/>
        <xsl:message select="concat('remaining:',count($remaining))"/>
        
        <xsl:variable name="merged" as="element()*">
            <!-- Include all pre-existing metadata -->
            <xsl:sequence select="$properties"/>
            
            <xsl:for-each-group select="$new/*" group-by="name()">
                <xsl:variable name="name" select="current-grouping-key()"/>
                <xsl:if test="not($properties/name() = $name)">
                    <xsl:sequence select="current-group()"/>
                </xsl:if>
            </xsl:for-each-group>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$remaining">
                <xsl:call-template name="merge-properties">
                    <xsl:with-param name="properties" select="$merged"/>
                    <xsl:with-param name="descriptions" select="$remaining"/>
                </xsl:call-template>
                
            </xsl:when>
            <xsl:otherwise>
                <!-- Sort properties by namespace in this order -->
                <xsl:variable name="ordered-namespaces" select="distinct-values(('http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'http://purl.org/vocab/frbr/core#', 'http://purl.org/dc/elements/1.1/',
                                                                              'http://schema.org/', 'http://www.nlb.no/bibliographic', 'http://www.nlb.no/production',
                                                                              $merged/namespace-uri()))"/>
                
                <!-- Within each namespace; sort elements in this order -->
                <xsl:variable name="ordered-elements" as="xs:string*">
                    <xsl:for-each select="$merged/name()">
                        <xsl:sort select="."/>
                        <xsl:sequence select="."/>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="ordered-elements" select="distinct-values((
                                                                           ('rdf:type'),
                                                                           ('frbr:translationOf'),
                                                                           ('dc:identifier','dc:title','dc:creator','dc:format','dc:language'),
                                                                           ('schema:exampleOfWork','schema:isbn'),
                                                                           $ordered-elements))"/>
                
                <xsl:for-each select="$ordered-namespaces">
                    <xsl:variable name="namespace" select="."/>
                    <xsl:for-each select="$ordered-elements">
                        <xsl:variable name="name" select="."/>
                        <xsl:sequence select="$merged[namespace-uri() = $namespace and name() = $name]"/>
                    </xsl:for-each>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>
