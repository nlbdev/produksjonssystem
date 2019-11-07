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
        
        Gaute Rønningen <gaute.ronningen@nlb.no>
        Jostein Austvik Jacobsen <jostein@nlb.no>
        
        Based on work by Per Sennels, NLB
        
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
    
    <!-- Semantics -->
    <xsl:template match="m:semantics" mode="spoken-math">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <xsl:template match="m:mspace | m:annotation" mode="spoken-math"/>
    <xsl:template match="m:mtext" mode="spoken-math">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <!-- Ignore: Content MathML -->
    <xsl:template match="m:annotation-xml[@encoding eq 'MathML-Content']" mode="#all"></xsl:template>
    
    <!-- m:msup is used to attach a superscript to an expression -->
    <xsl:template match="m:msup" mode="spoken-math">
        <xsl:choose>
            <xsl:when test="((local-name(child::element()[2]) eq 'mn') and matches(normalize-space(child::element()[2]), '^\d{1,3}$')) or ((local-name(child::element()[2]) eq 'mi') and matches(normalize-space(child::element()[2]), '^[a-z]$'))">
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('raised to', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('raised to', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('exponent end', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="m:msup[child::*[2] eq '2']" mode="spoken-math">
        <xsl:apply-templates select="child::*[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('squared', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:msup[(count(child::element()) eq 2) and ((local-name(child::element()[1]) eq 'mn') or ((local-name(child::element()[1]) eq 'mrow') and (count(child::element()[1]/child::element()) eq 2) and local-name(child::element()[1]/child::element()[1]) eq 'mo') and (normalize-space(child::element()[1]/child::element()[1]) eq '-') and (local-name(child::element()[1]/child::element()[2]) eq 'mn')) and (local-name(child::element()[2]) eq 'mtext') and (normalize-space(m:mtext) eq 'g')]"
        mode="spoken-math">
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('gon', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    
    <!-- m:msub is used to attach a subscript to an expression -->
    <xsl:template match="m:msub[(local-name(child::element()[1]) and (matches(normalize-space(child::element()[1]), '^[a-z]$', 'i') or matches(normalize-space(child::element()[1]), '^\p{IsGreek}$')) and (local-name(child::element()[2]) eq 'mn') and matches(normalize-space(child::element()[2]), '^\d+$'))]" mode="spoken-math">
        <xsl:apply-templates select="m:mi" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with the lower index', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mn" mode="#current"/>
    </xsl:template>
    <xsl:template match="m:msub[(count(m:mi) eq 2) and (matches(normalize-space(m:mi[1]), '^[a-z]$', 'i') or matches(normalize-space(m:mi[1]), '^\p{IsGreek}$')) and (matches(normalize-space(m:mi[2]), '^[a-z]$', 'i') or matches(normalize-space(m:mi[2]), '^\p{IsGreek}$'))]" mode="spoken-math">
        <xsl:apply-templates select="m:mi[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with the lower index', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mi[2]" mode="#current"/>
    </xsl:template>
    
    <!-- m:frac is used to display fractions -->
    <xsl:template match="m:mfrac" mode="spoken-math">
        <xsl:choose>
            <xsl:when test="every $e in child::element() satisfies(((local-name($e) eq 'mi') and matches($e, '^[a-z]$')) or ((local-name($e) eq 'mn') and matches($e, '^\d{1,3}$')))">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the fraction', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('divided by', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('division with dividend', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('and with divisor', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="m:mfrac[@bevelled eq 'true']" mode="spoken-math">
        <xsl:apply-templates select="child::*[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('divided by', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::*[2]" mode="#current"/>
    </xsl:template>
    <xsl:template match="m:mfrac[(count(child::element()) eq 2) and (every $c in child::element() satisfies local-name($c) eq 'mrow') and (every $c in m:mrow satisfies ((local-name($c/child::element()[1]) eq 'mo') and (normalize-space($c/child::element()[1]) eq '&#x02146;'))) and (count(m:mrow[2]/child::element()) eq 2) and (local-name(m:mrow[2]/child::element()[2]) eq 'mi') and (matches(m:mrow[2]/m:mi, '^[a-z]$'))]" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the derivative of', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates
            select="m:mrow[1]/child::element()[preceding-sibling::m:mo eq '&#x02146;']"
            mode="spoken-math"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with respect to', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mrow[2]/m:mi" mode="spoken-math"/>
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfrac[(count(child::element()) eq 2) and (every $c in child::element() satisfies local-name($c) eq 'mrow') and (local-name(m:mrow[1]/child::element()[1]) eq 'msup') and (local-name(m:mrow[1]/m:msup[1]/child::element()[1]) eq 'mo') and (local-name(m:mrow[1]/m:msup[1]/child::element()[2]) eq 'mn') and (normalize-space(m:mrow[1]/m:msup[1]/m:mo) eq '&#x02146;') and (normalize-space(m:mrow[1]/m:msup[1]/m:mn) eq '2') and (count(m:mrow[2]/child::element()) eq 2) and (local-name(m:mrow[2]/child::element()[1]) eq 'mo') and (local-name(m:mrow[2]/child::element()[2]) eq 'msup') and (normalize-space(m:mrow[2]/m:mo) eq '&#x02146;') and (local-name(m:mrow[2]/m:msup/child::element()[1]) eq 'mi') and (local-name(m:mrow[2]/m:msup/child::element()[2]) eq 'mn') and (matches(m:mrow[2]/m:msup/m:mi, '^[a-z]$')) and (normalize-space(m:mrow[2]/m:msup/m:mn) eq '2')]" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the second derivative of', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mrow[1]/child::element()[position() ge 2]"
            mode="spoken-math"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with respect to', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mrow[2]/m:msup/m:mi" mode="spoken-math"/>
        <xsl:text>, </xsl:text>
    </xsl:template>
    
    <!-- m:msubsup is used to attach both a subscript and a superscript, together, to an expression -->
    <xsl:template match="m:msubsup[m:mo[. eq '&#8747;']]" mode="spoken-math">
        <xsl:apply-templates select="child::*[1]" mode="#current"/>
    </xsl:template>
    <xsl:template match="m:msubsup[(local-name(child::element()[1]) eq 'mi') and (matches(normalize-space(child::element()[1]), '^[a-z]$', 'i') or matches(normalize-space(child::element()[1]), '^\p{IsGreek}$')) and (((local-name(child::element()[2]) eq 'mn') and matches(normalize-space(child::element()[2]), '^\d+$')) or ((local-name(child::element()[2]) eq 'mi') and (matches(normalize-space(child::element()[2]), '^[a-z]$', 'i') or matches(normalize-space(child::element()[2]), '^\p{IsGreek}$')))) and (local-name(child::element()[3]) eq 'mn') and matches(normalize-space(child::element()[3]), '^\d+$')]" mode="spoken-math">
        <xsl:apply-templates select="m:mi[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with the lower index', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[2]" mode="#current"/>
        <xsl:choose>
            <xsl:when test="normalize-space(child::element()[3]) eq '2'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('squared', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('in', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[3]" mode="#current"/>
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- m:mi is an identifier such as function names, variables or symbolic constants -->
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
    <xsl:template match="m:mi[contains(@mathvariant, 'bold')]" mode="spoken-math" priority="5">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('vector', .)" />
        <xsl:text> </xsl:text>
        <xsl:next-match/>
    </xsl:template>
    
    <!-- m:mtable is used to create tables or matrices -->
    <xsl:template match="m:mtable" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('a matrix with', .)" />
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:tall(count(m:mtr), .)"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('rows and with', .)" />
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:tall(count(m:mtr[1]/m:mtd), .)"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('columns', .)" />
        <xsl:text>: </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('matrix end', .)" />
    </xsl:template>
    
    <!-- m:mtr represents a row in a table or a matrix -->
    <xsl:template match="m:mtr" mode="spoken-math">
        <xsl:if test="count(following-sibling::m:mtr) eq 0">
            <xsl:text> </xsl:text>
            <xsl:value-of select="fnk:translate('and at last', .)" />
            <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:value-of select="fnk:ordenstall(1 + count(preceding-sibling::m:mtr), .)"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('row', .)" />
        <xsl:text>: </xsl:text>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <!-- m:mtd represents a cell in a table or a matrix -->
    <xsl:template match="m:mtd" mode="spoken-math">
        <xsl:choose>
            <xsl:when test="count(following-sibling::m:mtd) eq 0">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('and the last column', .)" />
                <xsl:text>: </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="fnk:ordenstall(1 + count(preceding-sibling::m:mtd), .)"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('column', .)" />
                <xsl:text>: </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates mode="spoken-math"/>
        <xsl:text> </xsl:text>
    </xsl:template>
    
    <!-- m:mo represents an operator in a broad sense -->
    <xsl:template match="m:mo" mode="spoken-math">
        <xsl:variable name="operator" as="xs:string" select="normalize-space(.)"/>
        <xsl:choose>
            <xsl:when test="matches($operator, '^(,|\.)$')">
                <xsl:value-of select="$operator"/>
            </xsl:when>
            <xsl:when test="$operator eq '...'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('et cetera', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '+'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('plus', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '='">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('equals', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8800;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('differ from', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&lt;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('is less than', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x226A;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('is much less than', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x2264;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('is less than or equal', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&gt;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('is greater than', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x226B;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('is much greater than', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x2265;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('is greater or equal to', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '-'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('minus', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq ':'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('divided by', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#177;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('plus-minus', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8723;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('minus-plus', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8901;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('times', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8594;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('goes against', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8743;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('and', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x02062;'">
                <xsl:choose>
                    <xsl:when test="not(exists(preceding-sibling::element()[1]/child::element()) or exists(following-sibling::element()[1]/child::element())) and matches(preceding-sibling::element()[1], '^\d{1,3}$') and matches(following-sibling::element()[1], '^[a-z]$')">
                        <xsl:text> </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="fnk:translate('times', .)" />
                        <xsl:text> </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$operator eq '&#8747;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('integral of', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8748;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the double integral of', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8749;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the triple integral of', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8750;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the contour integral of', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8518;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('with respect to', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '['">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('left bracket', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq ']'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('right bracket', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '{'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('left brace', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '}'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('right brace', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#10216;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('left angle bracket', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#10217;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('right angle bracket', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8289;' or $operator eq '&#8290;'">
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>
                    <xsl:value-of select="fnk:translate('unknown operator', .)" />
                    <xsl:text>: </xsl:text>
                    <xsl:value-of select="."/>
                </xsl:message>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('unknown operator', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="m:mo[normalize-space(.) eq '!'][exists(preceding-sibling::element()) and matches(local-name(preceding-sibling::element()[1]), '^(mi|mn)$')]" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the faculty', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mo[normalize-space(.) eq '&#8660;'][exists(preceding-sibling::element()) and exists(following-sibling::element())]" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('is equivalent of', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
 
    <!-- m:mfenced provides the possibility to add custom opening and closing parentheses -->
    <xsl:template match="m:mfenced" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('parenthesis', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('parenthesis end', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfenced[@open = '(' and @close eq ')']" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('parenthesis', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('parenthesis end', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfenced[@open = '[' and @close eq ']']" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('left bracket', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('right bracket', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfenced[@open = '{' and @close eq '}']" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('left brace', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('right brace', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfenced[@open = '&lt;' and @close eq '&gt;']" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('left angle bracket', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('right angle bracket', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfenced[@open = '|' and @close eq '|']" mode="spoken-math">
        <xsl:choose>
            <xsl:when test="(count(child::element()) eq 1) and exists(m:mi)">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the absolute value for', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:when
                test="(count(child::element()) eq 1) and exists(m:mrow) and (count(m:mrow/child::element()) eq 2) and exists(m:mrow/m:mo) and matches(normalize-space(m:mrow/m:mo), '^-$') and exists(m:mrow/m:mn) and matches(normalize-space(m:mrow/m:mn), '^\d+')">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the absolute value for', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the absolute value for the expression', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('absolute value end', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
   
    <!-- m:mrow is used to group sub-expressions -->
    <xsl:template match="m:mrow" mode="spoken-math">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <xsl:template match="m:mrow[(count(child::element()) eq 2) and ((local-name(child::element()[1]) eq 'mn') or ((local-name(child::element()[1]) eq 'mrow') and (count(child::element()[1]/child::element()) eq 2) and (local-name(child::element()[1]/child::element()[1]) eq 'mo') and (normalize-space(child::element()[1]/child::element()[1]) eq '-') and (local-name(child::element()[1]/child::element()[2]) eq 'mn'))) and (local-name(child::element()[2]) eq 'mi') and (normalize-space(m:mi) eq '&#176;')]"
        mode="spoken-math">
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
        <xsl:choose>
            <xsl:when test="child::element()[1] castable as xs:integer">
                <xsl:choose>
                    <xsl:when test="abs(child::element()[1]) eq 1">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="fnk:translate('degree', .)" />
                        <xsl:text> </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="fnk:translate('degrees', .)" />
                        <xsl:text>, </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('degrees', .)" />
                <xsl:text>, </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="m:mrow[(count(child::element()) eq 3) and (local-name(child::element()[1]) eq 'mi') and matches(normalize-space(child::element()[1]),'^(sin|cos|tan|arcsin|arccos|arctan|sinh|cosh|tanh|cot|sec|csc|cosec|arccot|arcsec|arccsc|arccosec|coth|sech|csch|cosech|arsinh|arcosh|artanh|arcoth|ln)$') and (local-name(child::element()[2]) eq 'mo') and (normalize-space(child::element()[2]) eq '&#8289;')]" mode="spoken-math">
        <xsl:variable name="funksjon" as="xs:string">
            <xsl:variable name="f" as="xs:string" select="normalize-space(child::element()[1])"/>
            <xsl:choose>
                <xsl:when test="$f eq 'sin'">
                    <xsl:value-of select="fnk:translate('sine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'cos'">
                    <xsl:value-of select="fnk:translate('cosine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'tan'">
                    <xsl:value-of select="fnk:translate('tangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arcsin'">
                    <xsl:value-of select="fnk:translate('arcus sine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arccos'">
                    <xsl:value-of select="fnk:translate('arcus cosine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arctan'">
                    <xsl:value-of select="fnk:translate('arcus tangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'sinh'">
                    <xsl:value-of select="fnk:translate('hyperbolic sine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'cosh'">
                    <xsl:value-of select="fnk:translate('hyperbolic cosine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'tanh'">
                    <xsl:value-of select="fnk:translate('hyperbolic tangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arsinh'">
                    <xsl:value-of select="fnk:translate('hyperbolic arcus sine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arcosh'">
                    <xsl:value-of select="fnk:translate('hyperbolic arcus cosine', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'artanh'">
                    <xsl:value-of select="fnk:translate('hyperbolic arcus tangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arcoth'">
                    <xsl:value-of select="fnk:translate('hyperbolic arcus cotangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'cot'">
                    <xsl:value-of select="fnk:translate('cotangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'sec'">
                    <xsl:value-of select="fnk:translate('secant', .)" />
                </xsl:when>
                <xsl:when test="($f eq 'cosec') or ($f eq 'csc')">
                    <xsl:value-of select="fnk:translate('cosecant', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arccot'">
                    <xsl:value-of select="fnk:translate('arcus cotangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'arcsec'">
                    <xsl:value-of select="fnk:translate('arcus secant', .)" />
                </xsl:when>
                <xsl:when test="($f eq 'arccosec') or ($f eq 'arccsc')">
                    <xsl:value-of select="fnk:translate('arcus cosecant', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'coth'">
                    <xsl:value-of select="fnk:translate('hyperbolic cotangent', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'sech'">
                    <xsl:value-of select="fnk:translate('hyperbolic secant', .)" />
                </xsl:when>
                <xsl:when test="($f eq 'csch') or ($f eq 'cosech')">
                    <xsl:value-of select="fnk:translate('hyperbolic cosecant', .)" />
                </xsl:when>
                <xsl:when test="$f eq 'ln'">
                    <xsl:value-of select="fnk:translate('the natural logarithm', .)" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="fnk:translate('unknown function', .)" />
                    <xsl:message>
                        <xsl:value-of select="fnk:translate('unknown function', .)" />
                        <xsl:text>: </xsl:text>
                        <xsl:value-of select="$f"/>
                    </xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:text> </xsl:text>
        <xsl:value-of select="$funksjon"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('to', .)" />
        <xsl:text> </xsl:text>
        <xsl:choose>
            <xsl:when test="matches(local-name(child::element()[3]), '^(mn|mi)$') or ((local-name(child::element()[3]) eq 'mfenced') and (count(m:mfenced/m:mrow) eq 1))">
                <xsl:apply-templates select="child::element()[3]" mode="spoken-math"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the expression', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::element()[3]" mode="spoken-math"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('expression end', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="m:mrow[(count(child::element()) eq 3) and (local-name(child::element()[1]) eq 'mi') and (local-name(child::element()[2]) eq 'mo') and (local-name(child::element()[3]) eq 'mfenced') and (matches(normalize-space(m:mi), '^[a-z]$', 'i') or matches(normalize-space(m:mi), '^\p{IsGreek}$')) and (normalize-space(m:mo) eq '&#8289;')]" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the function', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mi" mode="#current"/>
        <xsl:call-template name="present-arguments"/>
    </xsl:template>
    <xsl:template match="m:mrow[(local-name(child::element()[1]) eq 'munder') and (local-name(child::element()[2]) eq 'mo') and (normalize-space(child::element()[2]) eq '&#8289;') and (local-name(m:munder[1]/child::element()[1]) eq 'mo') and (normalize-space(m:munder[1]/m:mo[1]) eq 'lim')]" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('boundary value of', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[3]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('when', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:munder[1]/child::element()[2]" mode="#current"/>
    </xsl:template>
    <xsl:template match="m:mrow[(count(child::element()) eq 3) and (local-name(child::element()[1]) eq 'msup') and (local-name(child::element()[2]) eq 'mo') and (local-name(child::element()[3]) eq 'mfenced') and (local-name(m:msup/child::element()[1]) eq 'mi') and (matches(m:msup/m:mi, '^[a-z]$')) and (local-name(m:msup/child::element()[2]) eq 'mo') and ((normalize-space(m:msup/m:mo) eq '&#8242;') or (normalize-space(m:msup/m:mo) eq '&#8243;')) and (normalize-space(m:mo) eq '&#8289;')]"
        mode="spoken-math">
        <xsl:choose>
            <xsl:when test="normalize-space(m:msup/m:mo) eq '&#8243;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the second derivative of the function', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the derivative of the function', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="m:msup/child::element()[1]" mode="#current"/>
        <xsl:call-template name="present-arguments"/>
    </xsl:template>
    <xsl:template match="m:mrow[(count(child::element()) eq 3) and (local-name(child::element()[1]) eq 'munderover') and (local-name(child::element()[3]) eq 'mrow') and (local-name(m:munderover/child::element()[1]) eq 'mo') and matches(normalize-space(m:munderover/m:mo[1]),'^(&#8747;|&#8748;|&#8749;|&#8750;)$') and (count(m:mrow[last()]/child::element()) eq 2) and (local-name(m:mrow[last()]/child::element()[1]) eq 'mo') and (normalize-space(m:mrow[last()]/m:mo[1]) eq '&#8518;') and (local-name(m:mrow[last()]/child::element()[2]) eq 'mi') and matches(normalize-space(m:mrow[last()]/m:mi), '^[a-z]$')]" mode="spoken-math">
        <xsl:variable name="integraltegnet" as="xs:string" select="normalize-space(m:munderover/m:mo[1])"/>
        <xsl:choose>
            <xsl:when test="$integraltegnet eq '&#8747;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('integral', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$integraltegnet eq '&#8748;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the double integral', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$integraltegnet eq '&#8749;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the triple integral', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$integraltegnet eq '&#8750;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the contour integral', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('unknown integral', .)" />
                <xsl:text> </xsl:text>
                <xsl:message> <xsl:value-of select="fnk:translate('unknown integral', .)" /></xsl:message>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('from', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:munderover/child::element()[2]" mode="spoken-math"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('to', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:munderover/child::element()[3]" mode="spoken-math"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('of', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[2]" mode="spoken-math"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with respect to', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mrow[last()]/child::element()[2]" mode="spoken-math"/>
        <xsl:text> </xsl:text>
    </xsl:template>
    
    <!-- m:mn represents a numeric literal which is normally a sequence of digits with a possible separator -->
    <xsl:template match="m:mn" mode="spoken-math">
        <xsl:choose>
            <xsl:when test=". castable as xs:double">
                <xsl:if test="number(.) lt 0">
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="fnk:translate('minus', .)" />
                    <xsl:text> </xsl:text>
                </xsl:if>
                <xsl:value-of select="abs(.)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="spoken-math"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- m:mover is used to attach an accent or a limit over an expression -->
    <xsl:template match="m:mover[(count(child::element()) eq 2) and (local-name(child::element()[2]) eq 'mo') and (normalize-space(child::element()[2]) eq '&#8594;')]" mode="spoken-math">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('vector', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
    </xsl:template>
    
    <!-- m:msqrt is used to display square roots (no index is displayed) -->
    <xsl:template match="m:msqrt" mode="spoken-math">
        <xsl:choose>
            <xsl:when test="count(child::element()) eq 1 and (((local-name(child::element()[1]) eq 'mn') and matches(normalize-space(.), '^\d{1,3}$')) or ((local-name(child::element()[1]) eq 'mi') and matches(normalize-space(.), '^[a-z]$')))">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('square root of', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('square root of', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('square root end', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- m:mroot is used to display roots with an explicit index -->
    <xsl:template match="m:mroot[matches(normalize-space(child::element()[2]), '^(\d|[a-z])$')]" mode="spoken-math">
        <xsl:choose>
            <xsl:when test="matches(normalize-space(child::element()[2]), '^\d$')">
                <xsl:value-of select="normalize-space(child::element()[2])"/>
                <xsl:text>. </xsl:text>
                <xsl:value-of select="fnk:translate('squared', .)"/>
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="normalize-space(child::element()[2])"/>
                <xsl:text>-</xsl:text>
                <xsl:value-of select="fnk:translate('squared', .)"/>
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
    </xsl:template>
    
    <!-- Presenting the arguements in the formula -->
    <xsl:template name="present-arguments">
        <xsl:choose>
            <xsl:when test="(count(m:mfenced/element()) eq 1) and matches(local-name(m:mfenced/element()), '^(mi|mn)$')">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="m:mfenced/*" mode="spoken-math"/>
            </xsl:when>
            <xsl:when test="(count(m:mfenced/element()) gt 1) and (every $a in m:mfenced/element() satisfies matches(local-name($a), '^(mi|mn)$'))">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of', .)" />
                <xsl:text> </xsl:text>
                <xsl:for-each select="m:mfenced/element()">
                    <xsl:apply-templates select="." mode="spoken-math"/>
                    <xsl:choose>
                        <xsl:when test="position() eq last() - 1">
                            <xsl:text> </xsl:text>
                            <xsl:value-of select="fnk:translate('and', .)" />
                            <xsl:text> </xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text> </xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:when>
            <xsl:when test="m:mfenced/m:mrow">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of the expression', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="m:mfenced/*" mode="spoken-math"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('expression end', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of the expression', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="m:mfenced/*" mode="spoken-math"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('expression end', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>