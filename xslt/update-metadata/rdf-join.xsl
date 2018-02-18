<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:schema="http://schema.org/"
                xmlns:f="#"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:param name="metadata-dir" required="yes" as="xs:string"/>
    <xsl:param name="rdf-files" required="yes" as="xs:string"/>
    
    <xsl:template name="main">
        <xsl:variable name="rdf-file-uris" select="for $r in tokenize($rdf-files,'\s+') return string(resolve-uri($r, resolve-uri($metadata-dir)))" as="xs:string*"/>
        <xsl:variable name="descriptions" select="for $r in $rdf-file-uris return document($r)//rdf:Description" as="element()*"/>
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
        
        <xsl:call-template name="main-testable">
            <xsl:with-param name="descriptions" select="$descriptions"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="main-testable">
        <xsl:param name="descriptions" as="element()*"/>
        
        <xsl:variable name="result" as="element()">
            <rdf:RDF>
                <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
                <xsl:namespace name="schema" select="'http://schema.org/'"/>
                <xsl:namespace name="nlbprod" select="'http://www.nlb.no/production'"/>
                <xsl:namespace name="frbr" select="'http://purl.org/vocab/frbr/core#'"/>
                <xsl:namespace name="nlbbib" select="'http://www.nlb.no/bibliographic'"/>
                
                <xsl:for-each select="$descriptions/(@rdf:about, @rdf:ID)">
                    <xsl:sort/>
                    <xsl:variable name="about-or-id" select="."/>
                    <xsl:variable name="filtered-descriptions" select="f:select-descriptions($about-or-id,  $descriptions, ('bibliofil','quickbase','epub'))"/>
                    <rdf:Description>
                        <xsl:call-template name="unique-about-or-id">
                            <xsl:with-param name="descriptions" select="$filtered-descriptions"/>
                        </xsl:call-template>
                        
                        <xsl:call-template name="merge-properties">
                            <xsl:with-param name="descriptions" select="$filtered-descriptions"/>
                        </xsl:call-template>
                    </rdf:Description>
                </xsl:for-each>
            </rdf:RDF>
        </xsl:variable>
        <xsl:variable name="result" as="element()">
            <xsl:for-each select="$result">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="namespace::* | @*" exclude-result-prefixes="#all"/>
                    <xsl:copy-of select="* except *[(@rdf:about, @rdf:ID) = preceding-sibling::*/(@rdf:about, @rdf:ID)]" exclude-result-prefixes="#all"/>
                </xsl:copy>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="result" as="element()">
            <xsl:for-each select="$result">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select="namespace::* | @*" exclude-result-prefixes="#all"/>
                    <xsl:for-each select="*[starts-with(@rdf:about,'urn')]">
                        <xsl:sort select="@rdf:about"/>
                        <xsl:copy-of select="." exclude-result-prefixes="#all"/>
                    </xsl:for-each>
                    <xsl:for-each select="*[@rdf:about and not(starts-with(@rdf:about,'urn'))]">
                        <xsl:sort select="@rdf:about"/>
                        <xsl:copy-of select="." exclude-result-prefixes="#all"/>
                    </xsl:for-each>
                    <xsl:for-each select="*[not(@rdf:about)]">
                        <xsl:sort select="@rdf:ID"/>
                        <xsl:copy-of select="." exclude-result-prefixes="#all"/>
                    </xsl:for-each>
                </xsl:copy>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- move namespaces to root element and update references -->
        <xsl:for-each select="$result">
            <xsl:copy exclude-result-prefixes="#all">
                <xsl:copy-of select=".//namespace::*"/>
                <xsl:apply-templates select="@* | node()" mode="update-references">
                    <xsl:with-param name="descriptions" select="$descriptions" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:copy>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="@* | node()" mode="update-references">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@rdf:resource" mode="update-references">
        <xsl:param name="descriptions" as="element()*" tunnel="yes"/>
        <xsl:choose>
            <xsl:when test="substring-after(.,'#') = $descriptions/(@rdf:about, @rdf:ID)">
                <xsl:variable name="resource" as="attribute()">
                    <xsl:call-template name="unique-about-or-id">
                        <xsl:with-param name="descriptions" select="f:select-descriptions(substring-after(.,'#'),  $descriptions, ('bibliofil','quickbase','epub'))"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:attribute name="rdf:resource" select="concat('#',$resource)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Merges in new metadata recursively -->
    <xsl:template name="merge-properties" as="element()*">
        <xsl:param name="properties" select="()" as="element()*"/>
        <xsl:param name="descriptions" required="yes" as="element()*"/>
        
        <xsl:variable name="new" select="if (count($descriptions)) then $descriptions[1] else ()"/>
        <xsl:variable name="remaining" select="if (count($descriptions)) then $descriptions[position() gt 1] else ()"/>
        
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
    
    <xsl:function name="f:select-descriptions" as="element()*">
        <xsl:param name="about-or-id" as="xs:string"/>
        <xsl:param name="descriptions" as="element()*"/>
        <xsl:param name="sources" as="xs:string*"/>
        
        <xsl:variable name="referencing-descriptions" select="$descriptions[schema:exampleOfWork/substring-after(@rdf:resource,'#') = $about-or-id]/(string(@rdf:about), string(@rdf:ID))" as="xs:string*"/>
        <xsl:variable name="abouts-or-ids" select="distinct-values(($about-or-id, $descriptions[(@rdf:about, @rdf:ID) = $referencing-descriptions]/schema:exampleOfWork/substring-after(@rdf:resource,'#')))" as="xs:string+"/>
        
        <xsl:for-each select="$sources">
            <xsl:variable name="source" select="."/>
            <xsl:for-each select="$descriptions">
                <xsl:if test="string(@_source) = $source and $abouts-or-ids = (string(@rdf:about), string(@rdf:ID))">
                    <xsl:sequence select="."/>
                </xsl:if>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:function>
    
    <xsl:template name="unique-about-or-id">
        <xsl:param name="descriptions" as="element()+"/>
        
        <xsl:variable name="about" as="xs:string*">
            <xsl:for-each select="$descriptions/@rdf:about">
                <xsl:sort/>
                <xsl:sequence select="string(.)"/>
            </xsl:for-each>
            <xsl:for-each select="$descriptions/dc:source.urn-nbn/text()">
                <xsl:sort/>
                <xsl:sequence select="string(.)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="id" as="xs:string*">
            <xsl:for-each select="$descriptions/@rdf:ID">
                <xsl:sort/>
                <xsl:sequence select="string(.)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="count($about)">
                <xsl:attribute name="rdf:about" select="$about[1]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="rdf:ID" select="$id[1]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>
