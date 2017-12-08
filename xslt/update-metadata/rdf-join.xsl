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
        <rdf:RDF>
            <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
            <xsl:namespace name="schema" select="'http://schema.org/'"/>
            <xsl:namespace name="nlbprod" select="'http://www.nlb.no/production'"/>
            <xsl:namespace name="frbr" select="'http://purl.org/vocab/frbr/core#'"/>
            <xsl:namespace name="nlbbib" select="'http://www.nlb.no/bibliographic'"/>
            <xsl:variable name="descriptions" select="for $r in $rdf-file-uris return document($r)//rdf:Description[@rdf:about]"/>
            <xsl:for-each select="distinct-values($descriptions/@rdf:about)">
                <rdf:Description>
                    <xsl:attribute name="rdf:about" select="."/>
                    <xsl:variable name="annotated-properties" as="element()*">
                        <xsl:for-each select="$descriptions[@rdf:about=current()]">
                            <xsl:variable name="source" select="replace(replace(base-uri(),'.*/',''),'-.*','')"/>
                            <xsl:for-each select="*">
                                <xsl:copy>
                                    <xsl:copy-of select="@*"/>
                                    <xsl:attribute name="_source" select="$source"/>
                                    <xsl:copy-of select="node()"/>
                                </xsl:copy>
                            </xsl:for-each>
                        </xsl:for-each>
                    </xsl:variable>
                    
                    <!--
                        TODO:
                        - only include unique properties
                            - group properties with descendants by name()+@schema:name
                            - group properties without descendants by name()+text()
                            - if a property is defined in bibliofil, don't add the quickbase elements with the same names (compare by name())
                    -->
                    
                    <xsl:for-each select="$annotated-properties">
                        <xsl:copy>
                            <xsl:copy-of select="@* except @_source"/>
                            <xsl:copy-of select="node()"/>
                        </xsl:copy>
                    </xsl:for-each>
                </rdf:Description>
            </xsl:for-each>
        </rdf:RDF>
    </xsl:template>
    
</xsl:stylesheet>
