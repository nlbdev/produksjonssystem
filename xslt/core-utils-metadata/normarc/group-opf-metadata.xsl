<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:opf="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" omit-xml-declaration="yes"/>
    
    <xsl:param name="append-prefixes" select="''" as="xs:string"/>
    <xsl:param name="include-other-identifiers-placeholder" select="false()" as="xs:boolean"/>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/text()"/>
    
    <xsl:template match="opf:metadata">
        <xsl:variable name="metadata" select="." as="element()"/>
        
        <xsl:variable name="creativeWorkProperties" select="('dc:title', 'dc:creator', 'dc:language', 'dc:contributor', 'schema:bookEdition', 'dc:subject', 'dc:type.genre', 'dc:type.fiction', 'dc:type.literaryForm',
                                                             'series.issn', 'series.position', 'periodical', 'periodicity', 'magazine', 'newspaper',
                                                             .//*[starts-with(@name,'dc:title.') and not(ends-with(@name, '.part') or contains(@name, '.part.'))]/string(@name),
                                                             .//*[starts-with(@name,'dc:contributor.') and not(@name='dc:contributor.narrator')]/string(@name),
                                                             .//*[starts-with(@name,'dc:subject.')]/string(@name))"/>
        
        <xsl:variable name="format" select="(dc:format[not(@refines)])[1]/text()" as="xs:string?"/>
        
        <xsl:text>    </xsl:text>
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
            <xsl:if test="$append-prefixes">
                <xsl:attribute name="prefix" select="string-join((@prefix, $append-prefixes), ' ')"/>
            </xsl:if>
            
            <!-- edition identifier (dc:identifier) before everything else -->
            <xsl:call-template name="comment-line">
                <xsl:with-param name="text" select="concat('Boknummer for ', if ($format) then concat($format, '-') else '', 'utgaven')"/>
            </xsl:call-template>
            <xsl:for-each select="dc:identifier[not(@refines)]">
                <xsl:call-template name="copy-element">
                    <xsl:with-param name="metadata" select="$metadata"/>
                    <xsl:with-param name="element" select="."/>
                </xsl:call-template>
            </xsl:for-each>
            <xsl:call-template name="newline"/>
            
            <!-- reference to other editions -->
            <xsl:if test="$include-other-identifiers-placeholder">
                <xsl:call-template name="comment-line">
                    <xsl:with-param name="text" select="'Boknummer for andre utgaver'"/>
                </xsl:call-template>
                <xsl:call-template name="comment-line">
                    <xsl:with-param name="text" select="'REPLACEME_OTHER_IDENTIFIERS'"/> <!-- to be replaced in postprocessing with python which will make an API call to get the other idendifiers -->
                </xsl:call-template>
                <xsl:call-template name="newline"/>
            </xsl:if>
            
            <!-- creative work metadata -->
            <xsl:call-template name="comment-line">
                <xsl:with-param name="text" select="'Metadata for åndsverket'"/>
            </xsl:call-template>
            <xsl:for-each select="$creativeWorkProperties">
                <xsl:variable name="property" select="." as="xs:string"/>
                <xsl:variable name="elements" select="$metadata/*[not(@refines) and $property = (name(), @property)]" as="element()*"/>
                
                <xsl:for-each select="$elements">
                    <xsl:call-template name="copy-element">
                        <xsl:with-param name="metadata" select="$metadata"/>
                        <xsl:with-param name="element" select="."/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:for-each>
            <xsl:call-template name="newline"/>
            
            <!-- edition metadata -->
            <xsl:call-template name="comment-line">
                <xsl:with-param name="text" select="concat('Metadata for ', if ($format) then concat($format, '-') else '', 'utgaven')"/>
            </xsl:call-template>
            <xsl:for-each select="$metadata/*[not(@refines)]">
                <xsl:variable name="property" select="(@property, name())[1]" as="xs:string"/>
                <xsl:if test="not($property = $creativeWorkProperties) and not($property = 'dc:identifier')">
                    <xsl:call-template name="copy-element">
                        <xsl:with-param name="metadata" select="$metadata"/>
                        <xsl:with-param name="element" select="."/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:for-each>
            <xsl:call-template name="newline"/>
            
            <xsl:text>
        </xsl:text>
            
            <xsl:text>
    </xsl:text>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="comment-line">
        <xsl:param name="text" as="xs:string"/>
        <xsl:call-template name="newline"/>
        <xsl:comment select="concat(' ', $text, ' ')"/>
    </xsl:template>
    
    <xsl:template name="newline">
        <xsl:text>
        </xsl:text>
    </xsl:template>
    
    <xsl:template name="copy-element">
        <xsl:param name="metadata" as="element()"/>
        <xsl:param name="element" as="element()"/>
        
        <xsl:call-template name="newline"/>
        <xsl:copy-of select="$element" exclude-result-prefixes="#all"/>
        
        <xsl:variable name="trailing-space" select="$element/(following-sibling::node()[1] intersect following-sibling::text()[1])" as="text()?"/>
        <xsl:variable name="trailing-comment" select="($element | $trailing-space)/(following-sibling::node()[1] intersect following-sibling::comment()[1])[1]" as="comment()?"/>
        <xsl:if test="$trailing-space/matches(., ' +')">
            <xsl:copy-of select="$trailing-space" exclude-result-prefixes="#all"/>
            <xsl:copy-of select="$trailing-comment" exclude-result-prefixes="#all"/>
        </xsl:if>
        
        <xsl:for-each select="$metadata/*[@refines != '' and @refines = $element/concat('#', @id)]">
            <xsl:call-template name="copy-element">
                <xsl:with-param name="metadata" select="$metadata"/>
                <xsl:with-param name="element" select="."/>
            </xsl:call-template>
        </xsl:for-each>
    </xsl:template>
    
</xsl:stylesheet>