<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:schema="http://schema.org/"
                xmlns:nlb="http://www.nlb.no/"
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
                
                <xsl:for-each select="$descriptions">
                    <xsl:sort select="(@rdf:about, @rdf:ID)[1]"/>
                    <xsl:variable name="about-or-id" select="(@rdf:about, @rdf:ID)[1]"/>
                    <xsl:variable name="type" select="(rdf:type/@rdf:resource)[1]" as="xs:string"/>
                    <xsl:variable name="filtered-descriptions" select="f:select-descriptions($about-or-id,  $descriptions, ('bibliofil','quickbase','epub'), $type)"/>
                    
                    <xsl:if test="$filtered-descriptions">
                        <rdf:Description>
                            <xsl:call-template name="unique-about-or-id">
                                <xsl:with-param name="descriptions" select="$filtered-descriptions"/>
                                <xsl:with-param name="type" select="$type"/>
                            </xsl:call-template>
                            
                            <xsl:variable name="uniq" as="xs:string">
                                <xsl:call-template name="unique-about-or-id">
                                    <xsl:with-param name="descriptions" select="$filtered-descriptions"/>
                                    <xsl:with-param name="type" select="$type"/>
                                </xsl:call-template>
                            </xsl:variable>
                            
                            <xsl:call-template name="merge-properties">
                                <xsl:with-param name="descriptions" select="$filtered-descriptions"/>
                            </xsl:call-template>
                        </rdf:Description>
                    </xsl:if>
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
        <xsl:variable name="result" as="element()">
            <xsl:for-each select="$result">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:copy-of select=".//namespace::*"/>
                    <xsl:apply-templates select="@* | node()" mode="update-references">
                        <xsl:with-param name="descriptions" select="$descriptions" tunnel="yes"/>
                    </xsl:apply-templates>
                </xsl:copy>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- post-processing -->
        <xsl:variable name="result" as="element()">
            <xsl:apply-templates select="$result" mode="post-process"/>
        </xsl:variable>
        
        <xsl:copy-of select="$result" exclude-result-prefixes="#all"/>
    </xsl:template>
    
    <xsl:template match="@* | node()" mode="update-references">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@rdf:resource" mode="update-references">
        <xsl:param name="descriptions" as="element()+" tunnel="yes"/>
        <xsl:variable name="about-or-id" select="substring-after(.,'#')" as="xs:string"/>
        <xsl:variable name="type" select="($descriptions[(@rdf:about, @rdf:ID) = $about-or-id]/rdf:type/@rdf:resource)[1]" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="not($type)">
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:when>
            <xsl:when test="substring-after(.,'#') = $descriptions/(@rdf:about, @rdf:ID)">
                <xsl:variable name="resource" as="attribute()">
                    <xsl:call-template name="unique-about-or-id">
                        <xsl:with-param name="descriptions" select="f:select-descriptions($about-or-id,  $descriptions, ('bibliofil','quickbase','epub'), $type)"/>
                        <xsl:with-param name="type" select="$type"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:attribute name="rdf:resource" select="concat(if ($resource/local-name() = 'ID') then '#' else '',$resource)"/>
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
        
        <xsl:variable name="description-about-or-id" select="parent::rdf:Description/rdf:type/@rdf:resource" as="xs:string?"/>
        
        <xsl:variable name="new" select="if (count($descriptions)) then $descriptions[1] else ()"/>
        <xsl:variable name="remaining" select="if (count($descriptions)) then $descriptions[position() gt 1] else ()"/>
        
        <!-- prefer dc:identifier from EPUB -->
        <xsl:variable name="epub-identifier" select="($descriptions/dc:identifier[@nlb:metadata-source='EPUB'])[1]" as="element()?"/>
        <xsl:variable name="properties" select="if ($epub-identifier) then ($epub-identifier, $properties[not(name()='dc:identifier')]) else $properties"/>
        
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
        <xsl:param name="type" as="xs:string"/>
        <xsl:variable name="join-all-creative-works" select="true()" as="xs:boolean"/> <!-- can be turned into a parameter in the future if needed -->
        
        
        <xsl:variable name="join-all-creative-works" select="$join-all-creative-works and $type = 'http://schema.org/CreativeWork'" as="xs:boolean"/>
        <xsl:variable name="referencing-descriptions" select="$descriptions[schema:exampleOfWork/substring-after(@rdf:resource,'#') = $about-or-id]/(string(@rdf:about), string(@rdf:ID))" as="xs:string*"/>
        <xsl:variable name="abouts-or-ids" select="distinct-values(($about-or-id, $descriptions[(@rdf:about, @rdf:ID) = $referencing-descriptions]/schema:exampleOfWork/substring-after(@rdf:resource,'#')))" as="xs:string+"/>
        <xsl:variable name="abouts-or-ids" select="distinct-values(($abouts-or-ids, if ($join-all-creative-works) then $descriptions[rdf:type/@rdf:resource = 'http://schema.org/CreativeWork']/(string(@rdf:about), string(@rdf:ID)) else ()))" as="xs:string+"/>
        
        <xsl:for-each select="$sources">
            <xsl:variable name="source" select="."/>
            <xsl:for-each select="$descriptions">
                <xsl:if test="string(@_source) = $source and rdf:type/@rdf:resource = $type and $abouts-or-ids = (string(@rdf:about), string(@rdf:ID))">
                    <xsl:sequence select="."/>
                </xsl:if>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:function>
    
    <xsl:template name="unique-about-or-id">
        <xsl:param name="descriptions" as="element()+"/>
        <xsl:param name="type" as="xs:string"/>
        
        <xsl:variable name="descriptions" select="$descriptions[rdf:type/@rdf:resource = $type]" as="element()*"/>
        <xsl:if test="not($descriptions)">
            <xsl:message terminate="yes" select="concat('Could not determine unique reference of type ''',$type,''' amongst the descriptions: ', string-join($descriptions/rdf:type/@rdf:resource,', '))"/>
        </xsl:if>
        
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
    
    <xsl:template match="@* | node()" mode="post-process">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dc:title" mode="post-process">
        <xsl:variable name="issue" select="(ancestor::rdf:RDF/rdf:Description/@rdf:about[matches(.,'^.*websok.tnr=\d{12}$')]/replace(.,'^.*websok.tnr=\d{6}',''))[1]" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="$issue">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:apply-templates select="@* | node()" mode="#current"/>
                    <xsl:choose>
                        <xsl:when test="xs:integer(substring($issue,3,2)) gt 12">
                            <!-- IIYYYY (where II = issue number) -->
                            <xsl:variable name="number" select="substring($issue,1,2)"/>
                            <xsl:variable name="year" select="substring($issue,3)"/>
                            
                            <xsl:value-of select="concat(' ',$number,'/',$year)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <!-- YYMMDD -->
                            <xsl:variable name="year" select="substring($issue,1,2)"/>
                            <xsl:variable name="year" select="concat(if (xs:integer($year) gt xs:integer(replace(string(current-date()),'^..(..).*$','$1'))) then '19' else '20', $year)"/>
                            <xsl:variable name="month" select="substring($issue,3,2)"/>
                            <xsl:variable name="day" select="substring($issue,5,2)"/>
                            
                            <xsl:value-of select="concat(' ',$year,'-',$month,'-',$day)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>
