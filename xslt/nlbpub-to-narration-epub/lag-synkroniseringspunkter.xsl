<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Denne transformasjonen brukes på output fra transformasjonen basert på prepare-for-narration.xsl.
        
        Transformasjonen plasserer et div.synch-point-wrapper (med @id) rundt alle //section/p-elementer, som er direkte søsken (altså uten andre elementer mellom) og der ingen av disse p-elementene inneholder sideskift.
        p-elementer som ikke oppfyller disse kriteriene beholdes uforandret.
        
        Per Sennels, 14.02.2018
        
        …
        
        Alle p-elementer som står ved siden av hverandre, og som ikke inneholder sideskift, grupperes. Maks $maks-antall-p-per-synkpunkt per gruppe.
        
        Sideskift flyttes ikke lenger i denne XSLTen.
        
        Jostein Austvik Jacobsen, 06.02.2020
    -->

    <xsl:output method="xhtml" indent="no" include-content-type="no"/>

    <!-- 
        Her kan vi bestemme maks antall p-elementer som kan inngå i ét div.synch-point-wrapper element. 
        Er det flere p-elementer som skal "wrappes sammen", så fordeles de i flere  div.synch-point-wrapper element med omtrent like mange p per wrapper.
    -->
    <xsl:variable name="maks-antall-p-per-synkpunkt" as="xs:integer" select="4"/>
    
    <xsl:template match="/*">
        <xsl:message>lag-synkroniseringspunkter.xsl (2.0.0 / 2018-02-14)</xsl:message>
        <xsl:message>* Lager synkroniseringspunkter ... </xsl:message>
        
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="@* | node()" priority="-5" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:function name="f:types" as="xs:string*">
        <xsl:param name="element" as="element()"/>
        
        <xsl:sequence select="tokenize($element/@epub:type, '\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:classes" as="xs:string*">
        <xsl:param name="element" as="element()"/>
        
        <xsl:sequence select="tokenize($element/@class, '\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:filter-wrappable-elements" as="element()*">
        <xsl:param name="elements" as="node()*"/>
        
        <xsl:variable name="elements" select="$elements[self::p | self::div[f:classes(.) = 'linegroup']]"/>  <!-- select elements that we want to wrap -->
        <xsl:variable name="elements" select="$elements[not(descendant::p) and not(descendant::div)]"/>  <!-- prevent nested wrapping -->
        <xsl:variable name="elements" select="$elements[not(descendant::*[f:types(.) = 'pagebreak'])]"/>  <!-- exclude elements with pagebreaks -->
        
        <xsl:sequence select="$elements"/>
    </xsl:function>
    
    <xsl:template match="*[f:filter-wrappable-elements(*)]">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:for-each-group select="node()" group-adjacent="exists(self::*/f:filter-wrappable-elements(.)) or not(self::*)">
                <xsl:choose>
                    <xsl:when test="current-grouping-key()">
                        <xsl:call-template name="create-synch-point-wrapper">
                            <xsl:with-param name="nodes" select="current-group()" as="node()*"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="current-group()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template name="create-synch-point-wrapper" as="node()*">
        <xsl:param name="nodes" as="node()*"/>
        
        <xsl:choose>
            <xsl:when test="count($nodes[self::*]) le $maks-antall-p-per-synkpunkt">
                <!-- put everything in a single wrapper -->
                <div class="synch-point-wrapper" id="{generate-id()}">
                    <xsl:apply-templates select="$nodes"/>
                </div>
            </xsl:when>
            
            <xsl:when test="count($nodes[self::*]) gt $maks-antall-p-per-synkpunkt * 2">
                <!-- put the max amount possible in a wrapper, and recursively call this template on the remaining nodes -->
                <div class="synch-point-wrapper" id="{generate-id()}">
                    <xsl:apply-templates select="$nodes intersect ($nodes[self::*])[$maks-antall-p-per-synkpunkt]/(. | preceding-sibling::node())"/>
                </div>
                <xsl:call-template name="create-synch-point-wrapper">
                    <xsl:with-param name="nodes" select="$nodes intersect ($nodes[self::*])[$maks-antall-p-per-synkpunkt]/following-sibling::node()" as="node()*"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <!-- split the set of nodes across two wrappers -->
                <div class="synch-point-wrapper" id="{generate-id()}">
                    <xsl:apply-templates select="$nodes[position() lt count($nodes) div 2]"/>
                </div>
                <div class="synch-point-wrapper" id="{generate-id()}">
                    <xsl:apply-templates select="$nodes[position() ge count($nodes) div 2]"/>
                </div>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!--<!-\- wrap linegroups in synch-point-wrapper divs -\->
    <xsl:template match="div[tokenize(@class,'\s+') = 'linegroup']">
        <div class="synch-point-wrapper" id="{concat('nlb-sp-',generate-id())}">
            <xsl:next-match/>
        </div>
    </xsl:template>-->

</xsl:stylesheet>
