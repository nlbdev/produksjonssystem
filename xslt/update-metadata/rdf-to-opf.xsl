<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:nlb="http://www.nlb.no/"
                xmlns:nlbbib="http://www.nlb.no/bibliographic"
                xmlns:nlbprod="http://www.nlb.no/production"
                xmlns:schema="http://schema.org/"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:import href="iso-639.xsl"/>
    <xsl:import href="marcrel.xsl"/>
    
    <xsl:output indent="yes"/>
    
    <xsl:variable name="opf-allowed-dc-elements" select="('dc:identifier', 'dc:title', 'dc:language', 'dc:contributor', 'dc:coverage',
                                                          'dc:creator', 'dc:date', 'dc:description', 'dc:format', 'dc:publisher',
                                                          'dc:relation', 'dc:rights', 'dc:source', 'dc:subject', 'dc:type')"/>
    
    <xsl:template match="/rdf:RDF">
        <xsl:variable name="metadata" as="node()*">
            <xsl:call-template name="compile-metadata"/>
        </xsl:variable>
        <metadata>
            <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
            <xsl:namespace name="opf" select="'http://www.idpf.org/2007/opf'"/>
            <xsl:copy-of select="$metadata"/>
        </metadata>
    </xsl:template>
    
    <xsl:template name="compile-metadata" as="node()*">
        <xsl:variable name="work" select="(rdf:Description[rdf:type/@rdf:resource = 'http://schema.org/CreativeWork'])[1]"/>
        <xsl:variable name="epub" select="(rdf:Description[dc:format = 'EPUB'])[1]"/>
        <xsl:variable name="daisy202" select="(rdf:Description[dc:format = 'DAISY 2.02'])[1]"/>
        <xsl:variable name="braille" select="(rdf:Description[dc:format = 'Braille'])[1]"/>
        
        <xsl:text><![CDATA[
   ]]></xsl:text>
        <xsl:comment select="' Boknummer for EPUB-utgaven '"/>
        <xsl:text><![CDATA[
]]></xsl:text>
        <dc:identifier id="pub-id"><xsl:value-of select="$epub/dc:identifier[1]/(@schema:name, text())[1]"/></dc:identifier>
        
        <xsl:text><![CDATA[

]]></xsl:text>
        <xsl:comment select="' Boknummer for andre utgaver '"/>
        <xsl:text><![CDATA[
]]></xsl:text>
        <xsl:for-each select="//nlbprod:*[starts-with(local-name(),'identifier')]">
            <meta property="{name()}"><xsl:value-of select="(@schema:name, text())[1]"/></meta>
        </xsl:for-each>
        
        <xsl:text><![CDATA[

]]></xsl:text>
        <xsl:comment select="' Metadata for åndsverket og utgavene '"/>
        <xsl:text><![CDATA[
]]></xsl:text>
        <xsl:for-each select="('dc:title', 'dc:language', 'dc:creator', 'dc:contributor',
                               'dc:format', 'dc:publisher', 'dc:rights', 'dc:coverage', 'dc:date',
                               'dc:description', 'dc:relation', 'dc:source', 'dc:subject', 'dc:type',
                               'dcterms:', 'nordic:', 'schema:')">
            
            <xsl:variable name="meta" select="$work/*[starts-with(name(), current())]" as="element()*"/>
            <xsl:variable name="meta" select="if (count($meta)) then $meta else $epub/*[starts-with(name(), current())]" as="element()*"/>
            
            <xsl:for-each select="$meta">
                <xsl:sort select="name()"/>
                <xsl:sort select="(@schema:name, text())[1]"/>
                
                <xsl:call-template name="meta">
                    <xsl:with-param name="rdf-property" select="."/>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:for-each>
        
        <!-- Merk: dcterms:modified må ignoreres ved sammenligning, og oppdateres ved hver endring. Den er derfor ikke inkludert her. -->
    </xsl:template>
    
    <xsl:template name="meta" as="element()*">
        <xsl:param name="rdf-property" as="element()"/>
        <xsl:variable name="property" select="$rdf-property/name()" as="xs:string"/>
        <xsl:variable name="value" select="$rdf-property/(@schema:name, text())[1]" as="xs:string"/>
        <xsl:variable name="marcrel" select="if (starts-with($property,'dc:contributor.')) then nlb:role-to-marcrel(substring-after($property,'dc:contributor.')) else ()" as="xs:string?"/>
        <xsl:variable name="property" select="if ($marcrel) then 'dc:contributor' else $property" as="xs:string"/>
        <xsl:variable name="authority" select="if (count($rdf-property/nlbbib:bibliofil-id)) then 'http://ns.nb.no/normarc' else ()" as="xs:string?"/>
        <xsl:variable name="term" select="$rdf-property/nlbbib:bibliofil-id" as="xs:string?"/>
        <xsl:variable name="translation" select="$rdf-property/../*[name() = concat($property,'.no')]/(@schema:name, text())[1]"/>
        <xsl:variable name="display-as" select="if (starts-with($property, 'dc:creator') or starts-with($property, 'dc:contributor') and contains($value, ',')) then normalize-space(concat(substring-after($value,','),' ',substring-before($value,','))) else ()" as="xs:string?"/>
        
        <xsl:if test="$value and not($property = 'dcterms:modified') and not(ends-with($property,'.no'))">
            <xsl:element name="{if ($property = $opf-allowed-dc-elements) then $property else 'meta'}">
                
                <xsl:if test="not($property = $opf-allowed-dc-elements)">
                    <xsl:attribute name="property" select="$property"/>
                </xsl:if>
                
                <xsl:if test="$property = 'dc:subject' and count($authority)">
                    <xsl:attribute name="opf:authority" select="$authority"/>
                    <xsl:attribute name="opf:term" select="$term"/>
                </xsl:if>
                
                <xsl:if test="$translation">
                    <xsl:attribute name="opf:alt-rep-lang" select="'no'"/>
                    <xsl:attribute name="opf:alt-rep" select="$translation"/>
                </xsl:if>
                
                <xsl:if test="$marcrel">
                    <xsl:attribute name="opf:role" select="$marcrel"/>
                </xsl:if>
                
                <xsl:if test="$property = 'dc:source' and starts-with($value, 'urn:isbn')">
                    <xsl:attribute name="opf:scheme" select="'isbn'"/>
                </xsl:if>
                
                <xsl:choose>
                    <xsl:when test="starts-with($property,'dc:language') and string-length($value) = 3">
                        <xsl:value-of select="nlb:iso-639-3-to-iso-639-1($value)"/>
                    </xsl:when>
                    
                    <xsl:when test="$display-as">
                        <xsl:attribute name="opf:file-as" select="$value"/>
                        <xsl:value-of select="$display-as"/>
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:value-of select="$value"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:element>
        </xsl:if>
    </xsl:template>
    
</xsl:stylesheet>