<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" 
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="#" 
    exclude-result-prefixes="#all"
    version="2.0">
    
    <!-- 
        (c) 2019 NLB
        
        Gaute Rønningen
        Jostein Austvik Jacobsen
        
        Last edit: 07.11.2019
    -->
    
    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    <xsl:import href="utilities.xsl"/>
    
    <!-- Parameters -->
    <xsl:param name="preserve-visual-math" as="xs:boolean" select="true()"/>
    
    <!-- Output encoding -->
    <xsl:output method="xhtml" indent="yes" encoding="UTF-8" include-content-type="no" exclude-result-prefixes="#all" />
    
    <!-- Print a message to console -->
    <xsl:template match="/">
        <xsl:message>mathml-to-spoken-math.xsl (<xsl:value-of  select="current-dateTime()"/>)</xsl:message>
        <xsl:apply-templates/>
    </xsl:template>
    
    <!-- Match everything so we dont miss anything -->
    <xsl:template match="@* | node()" priority="-10">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- Replace MathML with spoken math -->
    <!-- Block math -->
    <xsl:template match="m:math[@display eq 'block']">
        <xsl:next-match/>
        <xsl:variable name="imgsrc" select="@altimg" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="$preserve-visual-math and $imgsrc">
                <figure class="image">
                    <xsl:copy-of select="@id | @xml:lang"/>
                    <img class="visual-math" src="{$imgsrc}" alt="{@alttext}"/>
                    <figcaption class="spoken-math"><xsl:call-template name="generate-spoken-math"/><xsl:text></xsl:text></figcaption>
                </figure>
            </xsl:when>
            <xsl:otherwise>
                <p class="spoken-math">
                    <xsl:copy-of select="@id | @xml:lang"/>
                    <xsl:call-template name="generate-spoken-math"/>
                </p>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Inline math -->
    <xsl:template match="m:math[@display eq 'inline']">
        <xsl:next-match/>
        <xsl:variable name="imgsrc" select="@altimg" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="$preserve-visual-math and $imgsrc">
                <span class="image">
                    <xsl:copy-of select="@id | @xml:lang"/>
                    <img class="visual-math" src="{$imgsrc}" alt="{@alttext}"/>
                    <span class="spoken-math"><xsl:call-template name="generate-spoken-math"/></span>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <span class="spoken-math">
                    <xsl:copy-of select="@id | @xml:lang"/>
                    <xsl:call-template name="generate-spoken-math"/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- If display attribute is not set, terminate -->
    <xsl:template match="m:math">
        <xsl:message terminate="yes">No display attribute found, terminating.</xsl:message>
    </xsl:template>
    
    <!-- Start generation of spoken math -->
    <xsl:template name="generate-spoken-math">
        <!-- Generating a string with all the math -->
        <xsl:variable name="spoken-math" as="xs:string*">
            <xsl:apply-templates mode="spoken-math"/>
        </xsl:variable>
        <!-- Presentation of the generated string -->
        <xsl:value-of select="fnk:translate('formula', .)" />
        <xsl:text> </xsl:text>
        <xsl:value-of select="normalize-space(string-join($spoken-math, ' '))"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('formula end', .)" />
    </xsl:template>
    
    <!-- m:mi is an identifier such as function names, variables or symbolic constants - https://developer.mozilla.org/en-US/docs/Web/MathML/Element/mi -->
    <xsl:template match="m:mi" mode="spoken-math">
        <xsl:variable name="operator" as="xs:string" select="normalize-space(.)"/>
        <xsl:choose>
            <xsl:when test="$operator eq '&#8734;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('unlimited', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="matches($operator, '^\p{Lu}$')">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('capital', .)" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="lower-case(.)"/>
            </xsl:when>
            <xsl:when test="$operator eq '&#8520;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the imaginary unit', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- m:mi Greek letters -->
    <xsl:template match="m:mi[matches(normalize-space(.), '^\p{IsGreek}$')]" mode="spoken-math">
        <xsl:variable name="uc" as="xs:integer" select="string-to-codepoints(normalize-space(.))"/>
        <xsl:choose>
            <xsl:when test="$uc ge 945">
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('capital', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:choose>
            <xsl:when test="($uc eq 945) or ($uc eq 913)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('alfa', .)" />
            </xsl:when>
            <xsl:when test="($uc eq 946) or ($uc eq 914)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('beta', .)" />
            </xsl:when>
            <xsl:when test="($uc eq 947) or ($uc eq 915)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('gamma', .)" />
            </xsl:when>
            <xsl:when test="($uc eq 948) or ($uc eq 916)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('delta', .)" />
            </xsl:when>
            <xsl:when test="($uc eq 949) or ($uc eq 917)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('epsilon', .)" />
            </xsl:when>
            <xsl:when test="($uc eq 960) or ($uc eq 928)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('pi', .)" />
            </xsl:when>
            <xsl:when test="($uc eq 966) or ($uc eq 934) or ($uc eq 981)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('phi', .)" />
            </xsl:when>
            <xsl:when test="($uc eq 969) or ($uc eq 937)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('omega', .)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="fnk:translate('unknown greek letter', .)" />
                    <xsl:text>: </xsl:text>
                    <xsl:value-of select="$uc"/>
                </xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>