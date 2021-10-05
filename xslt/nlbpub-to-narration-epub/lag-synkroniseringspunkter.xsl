<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Denne transformasjonen brukes på output fra transformasjonen basert på prepare-for-narration.xsl.
        
        Transformasjonen plasserer et div.synch-point-wrapper (med @id) rundt alle //section/p-elementer, som er direkte søsken (altså uten andre elementer mellom) og der ingen av disse p-elementene inneholder sideskift.
        p-elementer som ikke oppfyller disse kriteriene beholdes uforandret.
        
        Per Sennels, 14.02.2018
    -->

    <xsl:output method="xhtml" indent="no" include-content-type="no"/>

    <!-- 
        Her kan vi bestemme maks antall p-elementer som kan inngå i ét div.synch-point-wrapper element. 
        Er det flere p-elementer som skal "wrappes sammen", så fordeles de i flere  div.synch-point-wrapper element med omtrent like mange p per wrapper.
    -->
    <xsl:variable name="maks-antall-p-per-synkpunkt" as="xs:integer" select="4"/>

    <xsl:template match="/">
        <xsl:message>lag-synkroniseringspunkter.xsl</xsl:message>
        <xsl:message>* Transformerer ... </xsl:message>
        <xsl:message>* Lager synkroniseringspunkter ... </xsl:message>

        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="@* | node()" priority="-5" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section" name="handle-as-section">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            
            <xsl:for-each-group select="*" group-adjacent="boolean(self::p and not(descendant::*[tokenize(@epub:type, '\s+') = ('pagebreak', 'noteref')]))">
                <xsl:choose>
                    <xsl:when test="current-grouping-key()">
                        <xsl:call-template name="create-synch-point-wrapper-div">
                            <xsl:with-param name="elements" select="current-group()"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="current-group()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="create-synch-point-wrapper-div">
        <xsl:param name="elements" as="element()*"/>
        
        <!-- Some arithmetic to distribute the elements evenly across the correct number of wrappers -->
        <xsl:variable name="number-of-wrappers" as="xs:integer" select="xs:integer(ceiling(count($elements) div $maks-antall-p-per-synkpunkt))"/>
        <xsl:variable name="elements-per-wrapper" as="xs:integer" select="xs:integer(ceiling(count($elements) div $number-of-wrappers))"/>
        <xsl:variable name="wrapper-id" select="generate-id($elements[1])"/>
        
        <!-- Distribute the elements into wrappers (Note that if all elements fit within a single wrapper, then this for-each will have no effect) -->
        <xsl:for-each select="1 to $number-of-wrappers - 1">
            <xsl:variable name="elements-in-this-wrapper" select="$elements[(position() ge (current() - 1) * $elements-per-wrapper + 1) and position() le (current() * $elements-per-wrapper)]"/>
            <div class="synch-point-wrapper" id="{concat('nlb-sp-', $wrapper-id, '-', current())}">
                <xsl:apply-templates select="$elements-in-this-wrapper">
                    <xsl:with-param name="wrapped" select="true()" tunnel="yes"/>
                </xsl:apply-templates>
            </div>
        </xsl:for-each>
        
        <!-- And then the rest of the elements -->
        <xsl:variable name="elements-in-this-wrapper" select="$elements[position() ge (($number-of-wrappers - 1) * $elements-per-wrapper + 1)]"/>
        <div class="synch-point-wrapper" id="{concat('nlb-sp-', $wrapper-id, '-', $number-of-wrappers)}">
            <xsl:apply-templates select="$elements-in-this-wrapper">
                <xsl:with-param name="wrapped" select="true()" tunnel="yes"/>
            </xsl:apply-templates>
        </div>
    </xsl:template>
    
    <!-- wrap linegroups in synch-point-wrapper divs -->
    <xsl:template match="div[tokenize(@class,'\s+') = 'linegroup']">
        <xsl:call-template name="handle-as-section"/>
    </xsl:template>
    
    <xsl:template match="p">
        <xsl:param name="wrapped" select="false()" tunnel="yes"/>
        <xsl:choose>
            <xsl:when test="$wrapped">
                <xsl:next-match/>
            </xsl:when>
            
            <xsl:when test="descendant::*[tokenize(@epub:type, '\s+') = ('pagebreak', 'noteref')]">
                <xsl:copy exclude-result-prefixes="#all">
                    <xsl:apply-templates select="@*"/>

                    <xsl:variable name="this" select="."/>
                    <xsl:variable name="stop-at" select="descendant::*[tokenize(@epub:type, '\s+') = ('pagebreak', 'noteref')]"/>
                    <xsl:variable name="wrapper-id" select="generate-id()"/>
                    
                    <xsl:for-each-group select="descendant::node()" group-adjacent="boolean(not(self::node() intersect $stop-at/descendant-or-self::node()))">
                        <xsl:choose>
                            <xsl:when test="current-grouping-key()">
                                <xsl:call-template name="create-synch-point-wrapper-span">
                                    <xsl:with-param name="wrapper-id" select="concat($wrapper-id, '-', position())"/>
                                    <xsl:with-param name="nodes" select="current-group()/ancestor-or-self::node() intersect $this/node()"/>
                                    <xsl:with-param name="descendants" select="current-group()"/>
                                </xsl:call-template>
                            </xsl:when>
                            <xsl:when test="self::node() intersect $stop-at">
                                <xsl:apply-templates select="current-group() intersect $stop-at"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- descendants of $stop-at => ignore, already processed -->
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:copy>
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="create-synch-point-wrapper-span">
        <xsl:param name="wrapper-id" as="xs:string"/>
        <xsl:param name="nodes" as="node()*"/>
        <xsl:param name="descendants" as="node()*"/>
        
        <span class="synch-point-wrapper" id="{concat('nlb-sp-', $wrapper-id)}">
            <xsl:apply-templates select="$nodes" mode="filter-descendants">
                <xsl:with-param name="wrapped" select="true()" tunnel="yes"/>
                <xsl:with-param name="descendants" select="$descendants"/>
            </xsl:apply-templates>
        </span>
    </xsl:template>
    
    <xsl:template match="node()" mode="filter-descendants">
        <xsl:param name="descendants" as="node()*"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@* except @id" exclude-result-prefixes="#all"/>
            <xsl:if test="boolean(self::node() intersect $descendants)">
                <xsl:copy-of select="@id"/>
            </xsl:if>
            <xsl:apply-templates select="node()[./descendant-or-self::node() intersect $descendants]" mode="#current">
                <xsl:with-param name="descendants" select="$descendants"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="a[tokenize(@epub:type, '\s+') = 'noteref']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:if test="not(contains(lower-case(string-join(.//text(), '')), 'note'))">
                <xsl:text>Note </xsl:text>
            </xsl:if>
            <xsl:value-of select="replace(normalize-space(.), '(^[\[\(]|[\]\)]$)', '')"/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
