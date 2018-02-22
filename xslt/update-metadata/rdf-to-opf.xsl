<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:nlb="http://www.nlb.no/"
                xmlns:nlbbib="http://www.nlb.no/bibliographic"
                xmlns:nlbprod="http://www.nlb.no/production"
                xmlns:nordic="http://www.mtm.se/epub/"
                xmlns:schema="http://schema.org/"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:dcterms="http://purl.org/dc/terms/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:import href="normarc/iso-639.xsl"/>
    <xsl:import href="normarc/marcrel.xsl"/>
    
    <xsl:output indent="no"/>
    
    <xsl:param name="epub-version" select="'3.0'" as="xs:string"/>
    <xsl:param name="format" select="''" as="xs:string"/>
    <xsl:param name="update-identifier" select="false()" as="xs:boolean"/>
    
    <xsl:variable name="opf-allowed-dc-elements" select="('dc:identifier', 'dc:title', 'dc:language', 'dc:contributor', 'dc:coverage',
                                                          'dc:creator', 'dc:date', 'dc:description', 'dc:format', 'dc:publisher',
                                                          'dc:relation', 'dc:rights', 'dc:source', 'dc:subject', 'dc:type')"/>
    
    <xsl:template name="test">
        <xsl:param name="context" as="element()"/>
        <xsl:param name="epub-version" select="$epub-version" as="xs:string"/>
        <xsl:param name="format" select="$format" as="xs:string"/>
        <xsl:param name="update-identifier" select="$update-identifier" as="xs:boolean"/>
        <xsl:for-each select="$context">
            <xsl:call-template name="main">
                <xsl:with-param name="epub-version" select="$epub-version" tunnel="yes"/>
                <xsl:with-param name="epubVersion" select="$epub-version"/>
                <xsl:with-param name="format" select="$format"/>
                <xsl:with-param name="update-identifier" select="$update-identifier" tunnel="yes"/>
            </xsl:call-template>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="/rdf:RDF">
        <xsl:call-template name="main">
            <xsl:with-param name="epub-version" select="$epub-version" tunnel="yes"/>
            <xsl:with-param name="epubVersion" select="$epub-version"/>
            <xsl:with-param name="format" select="$format"/>
            <xsl:with-param name="update-identifier" select="$update-identifier" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="main">
        <xsl:param name="epubVersion" as="xs:string"/>
        <xsl:param name="format" as="xs:string"/>
        <xsl:variable name="metadata" as="node()*">
            <xsl:call-template name="compile-metadata">
                <xsl:with-param name="format" select="$format"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:text><![CDATA[
    ]]></xsl:text>
        <metadata>
            <xsl:namespace name="dc" select="'http://purl.org/dc/elements/1.1/'"/>
            <xsl:namespace name="opf" select="'http://www.idpf.org/2007/opf'"/>
            
            <xsl:variable name="reserved-prefixes" select="if ($epubVersion = '3.1') then ('a11y','dcterms','epubsc','marc','media','onix','rendition','schema','xsd') else ('dcterms','marc','media','onix','xsd')"/>
            <xsl:variable name="metadata-prefixes" select="distinct-values($metadata/@property[contains(.,':')]/substring-before(.,':')[not(.=$reserved-prefixes)])"/>
            <xsl:variable name="mappings" select="for $p in $metadata-prefixes return concat($p, ': ', namespace-uri-for-prefix($p, (//*[substring-before(name(),':') = $p])[1]))"/>
            <xsl:variable name="prefixes" select="string-join($mappings,' ')"/>
            <xsl:if test="$prefixes">
                <xsl:attribute name="prefix" select="$prefixes"/>
            </xsl:if>
            
            <xsl:copy-of select="$metadata"/>
            <xsl:text><![CDATA[
    ]]></xsl:text>
        </metadata>
    </xsl:template>
    
    <xsl:template name="compile-metadata" as="node()*">
        <xsl:param name="format" as="xs:string"/>
        <xsl:param name="update-identifier" as="xs:boolean" tunnel="yes"/>
        <xsl:variable name="work" select="(rdf:Description[rdf:type/@rdf:resource = 'http://schema.org/CreativeWork'])[1]"/>
        <xsl:variable name="epub" select="(rdf:Description[dc:format = 'EPUB'])[1]"/>
        <xsl:variable name="daisy202" select="(rdf:Description[dc:format = 'DAISY 2.02'])[1]"/>
        <xsl:variable name="braille" select="(rdf:Description[dc:format = 'Braille'])[1]"/>
        <xsl:variable name="publication" select="if ($format) then (rdf:Description[dc:format = $format])[1] else ()"/>
        
        <xsl:variable name="identifier" select="if ($update-identifier) then ($publication, $epub)[1]/dc:identifier[1] else $epub[1]/dc:identifier[1]"/>
        
        <xsl:if test="$identifier">
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <xsl:comment select="concat(' Boknummer for ', string(($identifier/../dc:format[1])/text()), '-utgaven ')"/>
            
            <xsl:call-template name="meta">
                <xsl:with-param name="rdf-property" select="$identifier"/>
                <xsl:with-param name="id" select="'pub-id'"/>
            </xsl:call-template>
        </xsl:if>
        
        
        <xsl:text><![CDATA[
        
        ]]></xsl:text>
        <xsl:comment select="' Boknummer for andre utgaver '"/>
        
        <xsl:for-each select="//nlbprod:*[starts-with(local-name(),'identifier')]">
            <xsl:call-template name="meta">
                <xsl:with-param name="rdf-property" select="."/>
            </xsl:call-template>
            <xsl:if test="../schema:isbn[1]">
                <xsl:call-template name="meta">
                    <xsl:with-param name="rdf-property" select="../schema:isbn[1]"/>
                    <xsl:with-param name="rename" select="replace(name(),'nlbprod:identifier','nlbprod:isbn')"/>
                </xsl:call-template>
            </xsl:if>
        </xsl:for-each>
        
        <xsl:text><![CDATA[
        
        ]]></xsl:text>
        <xsl:comment select="' Metadata for åndsverket og utgavene '"/>
        <xsl:for-each select="('dc:title', 'dc:language', 'dc:creator', 'dc:contributor',
                               'dc:format', 'dc:publisher', 'dc:rights', 'dc:coverage', 'dc:date',
                               'dc:description', 'dc:relation', 'dc:source', 'dc:subject', 'dc:type',
                               distinct-values((//dcterms:* | //nordic:* | //schema:*)[@schema:name or text()]/(tokenize(name(),'\.')[1])))">
            
            <xsl:variable name="meta" select="($work/*, $publication/(* except schema:isbn))[starts-with(name(), current())]" as="element()*"/> <!-- TODO: find a better way to handle publication ISBNs -->
            <xsl:variable name="meta" select="if (count($meta)) then $meta else $epub/*[starts-with(name(), current())]" as="element()*"/>
            
            <xsl:for-each select="$meta">
                <xsl:sort select="name()"/>
                <xsl:sort select="(@schema:name, text())[1]"/>
                
                <xsl:call-template name="meta">
                    <xsl:with-param name="rdf-property" select="."/>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:for-each>
        <xsl:text><![CDATA[
]]></xsl:text>
        
        <!-- Merk: dcterms:modified må ignoreres ved sammenligning, og oppdateres ved hver endring. Den er derfor ikke inkludert her. -->
    </xsl:template>
    
    <xsl:template name="meta" as="node()*">
        <xsl:param name="epub-version" as="xs:string" tunnel="yes"/>
        <xsl:param name="rdf-property" as="element()"/>
        <xsl:param name="rename" as="xs:string?"/>
        <xsl:param name="id" as="xs:string?"/>
        <xsl:variable name="property" select="$rdf-property/name()" as="xs:string"/>
        <xsl:if test="not($rdf-property/(@schema:name, text())[1])">
            <xsl:message select="$rdf-property"/>
        </xsl:if>
        <xsl:variable name="value" select="$rdf-property/(@schema:name, text())[1]" as="xs:string"/>
        <xsl:variable name="marcrel" select="if ($epub-version = '3.1' and starts-with($property,'dc:contributor.')) then nlb:role-to-marcrel(substring-after($property,'dc:contributor.')) else ()" as="xs:string?"/>
        <xsl:variable name="property" select="if ($marcrel) then 'dc:contributor' else $property" as="xs:string"/>
        <xsl:variable name="authority" select="if (count($rdf-property/nlbbib:bibliofil-id)) then 'http://ns.nb.no/normarc' else ()" as="xs:string?"/>
        <xsl:variable name="term" select="$rdf-property/nlbbib:bibliofil-id" as="xs:string?"/>
        <xsl:variable name="translation" select="$rdf-property/../*[name() = concat($property,'.no')]/(@schema:name, text())[1]"/>
        <xsl:variable name="metadata-source" select="$rdf-property/@nlb:metadata-source"/>
        
        <xsl:if test="$value and not($property = 'dcterms:modified') and not(ends-with($property,'.no'))">
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <xsl:variable name="property" select="if ($rename) then $rename else $property"/>
            <xsl:element name="{if ($property = $opf-allowed-dc-elements) then $property else 'meta'}">
                
                <xsl:if test="not($property = $opf-allowed-dc-elements)">
                    <xsl:attribute name="property" select="$property"/>
                </xsl:if>
                
                <xsl:if test="$id">
                    <xsl:attribute name="id" select="$id"/>
                </xsl:if>
                
                <xsl:if test="$epub-version = '3.1'">
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
                </xsl:if>
                
                <xsl:choose>
                    <xsl:when test="starts-with($property,'dc:language') and string-length($value) = 3">
                        <xsl:value-of select="nlb:iso-639-3-to-iso-639-1($value)"/>
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:value-of select="$value"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:element>
            <xsl:if test="$metadata-source">
                <xsl:text> </xsl:text>
                <xsl:comment select="concat(' ',$metadata-source,' ')"/>
            </xsl:if>
        </xsl:if>
    </xsl:template>
    
</xsl:stylesheet>