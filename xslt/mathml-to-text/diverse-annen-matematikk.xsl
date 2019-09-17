<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" 
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" 
    exclude-result-prefixes="xs m fnk"
    version="2.0">

    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 21.01.2019
        Gaute Rønningen, 09.09.2019
    -->
    
    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    <xsl:import href="utilities.xsl"/>

    <!-- Templates: -->
    <xsl:template match="m:semantics" mode="verbal-matte">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="m:mspace | m:annotation" mode="verbal-matte"/>

    <xsl:template match="m:mtext" mode="verbal-matte">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <!--
        Tar bort denne: det er ikke slik vi håndterer integraler
        <xsl:template match="m:msubsup/m:mo[. eq '&#8747;']" mode="verbal-matte">
        <xsl:text> integralet fra </xsl:text>
        <xsl:apply-templates select="following-sibling::*[1]" mode="#current"/>
        <xsl:text> til </xsl:text>
        <xsl:apply-templates select="following-sibling::*[2]" mode="#current"/>
        <xsl:text> av </xsl:text>
    </xsl:template>-->

    <xsl:template match="m:msubsup[m:mo[. eq '&#8747;']]" mode="verbal-matte">
        <xsl:apply-templates select="child::*[1]" mode="#current"/>
    </xsl:template>

    <xsl:template match="m:msup" mode="verbal-matte">
        <!-- Vi har to former:
            * standardform "... opphøyd i  ... eksponent slutt"
            * kortform "... i ..."
            Drn siste brukes når eksponenten er et tall med tre sifre eller færre, eller nå det er et symbol med betgnelse a-z
        -->
        <xsl:choose>
            <xsl:when
                test="
                    (
                    (local-name(child::element()[2]) eq 'mn')
                    and
                    matches(normalize-space(child::element()[2]), '^\d{1,3}$')
                    )
                    or
                    (
                    (local-name(child::element()[2]) eq 'mi')
                    and
                    matches(normalize-space(child::element()[2]), '^[a-z]$')
                    )">
                <!-- kortform -->
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('raised to', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <!-- standardform -->
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

    <xsl:template match="m:msup[child::*[2] eq '2']" mode="verbal-matte">
        <!-- Kan gjøre denne strengere ved å kreve at andre barn skal være 'mn' -->

        <xsl:apply-templates select="child::*[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('squared', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>

    <xsl:template match="m:mfrac" mode="verbal-matte">
        <xsl:choose>
            <!-- Hvis alle (det vil begge) barna er enten mi- eller mn-elementer, med passe enkelt innhold, presenter det enkelt ... -->
            <xsl:when
                test="
                    every $e in child::element()
                        satisfies(((local-name($e) eq 'mi') and matches($e, '^[a-z]$')) or ((local-name($e) eq 'mn') and matches($e, '^\d{1,3}$')))">
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
                <!-- ... og hvis ikke, full pakke: -->
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
    <xsl:template match="m:mfrac[@bevelled eq 'true']" mode="verbal-matte">
        <!--<xsl:text> brøk med teller </xsl:text>-->
        <xsl:apply-templates select="child::*[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('divided by', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::*[2]" mode="#current"/>
        <!--<xsl:text> brøk slutt </xsl:text>-->
    </xsl:template>

    <xsl:template match="m:annotation-xml[@encoding eq 'MathML-Content']" mode="#all">
        <!-- ignorer dette -->
    </xsl:template>

    <xsl:template match="m:mtable" mode="verbal-matte">
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

    <xsl:template match="m:mtr" mode="verbal-matte">
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

    <xsl:template match="m:mtd" mode="verbal-matte">
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
        <xsl:apply-templates mode="verbal-matte"/>
        <xsl:text> </xsl:text>
    </xsl:template>

    <xsl:template match="m:mo" mode="verbal-matte">
        <xsl:variable name="operator" as="xs:string" select="normalize-space(.)"/>
        <xsl:choose>
            <xsl:when test="matches($operator, '^(,|\.)$')">
                <!-- Her brukes altså mo elementet for å ivareta et skilletegn. Dette er lov, se https://www.w3.org/TR/MathML3/chapter3.html#presm.mo
                    Litt usikker på hva som er lurt, men i første omgang så kan vi bare beholde dette skilletegnet.
                    Et alternativ kan være å ignorere det.
                -->
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
                <!-- Dette er &InvisibleTimes;, så egentlig en implisitt multiplikasjon -->
                <!-- Vi håndterer dette ved å se på søsken før og etter:
                    Dersom 
                    * ingen av dem har barn
                    * og søsken før består av inntil tre siffer
                    * og søsken etter består av ett alfabetisk tegn (a-z)
                -->
                <xsl:choose>
                    <xsl:when
                        test="
                            not(exists(preceding-sibling::element()[1]/child::element()) or exists(following-sibling::element()[1]/child::element()))
                            and
                            matches(preceding-sibling::element()[1], '^\d{1,3}$')
                            and
                            matches(following-sibling::element()[1], '^[a-z]$')
                            ">
                        <!--<xsl:text> (tom) </xsl:text>     
                        <xsl:value-of select="exists(following-sibling::element()[1]/child::element())"/>
                        <xsl:value-of select="exists(preceding-sibling::element()[1]/child::element())"/>-->
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

    <xsl:template
        match="m:mo[normalize-space(.) eq '!'][exists(preceding-sibling::element()) and matches(local-name(preceding-sibling::element()[1]), '^(mi|mn)$')]"
        mode="verbal-matte">
        <!-- Krever altså at foregående element før <mo>!</mo> finnes, og at det er mi eller mn -->
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the faculty', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfenced" mode="verbal-matte">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('parenthesis', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('parenthesis end', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>

    <xsl:template match="m:mfenced[@open = '|' and @close eq '|']" mode="verbal-matte">
        <xsl:choose>
            <xsl:when test="(count(child::element()) eq 1) and exists(m:mi)">
                <!-- Signatur
            <mfenced open="|" close="|">
                <mi>[hva som helst</mi>
            </mfenced> -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the absolute value for', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:when
                test="
                    (count(child::element()) eq 1) (: ett barn av mfenced :)
                    and exists(m:mrow) (: og det er mrow :)
                    and (count(m:mrow/child::element()) eq 2) (: som har to barn :)
                    and exists(m:mrow/m:mo) (: nemlig mo :)
                    and matches(normalize-space(m:mrow/m:mo), '^-$') (: som inneholder et minustegn :)
                    and exists(m:mrow/m:mn) (: og mn :)
                    and matches(normalize-space(m:mrow/m:mn), '^\d+') (: som inneholder ett eller flere sifre :)
                    ">
                <!-- Signatur
                <mfenced open="|" close="|">
                    <mrow>
                        <mo>-</mo>
                        <mn>[ett eller flere sifre]</mn>
                    </mrow>
                </mfenced> -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the absolute value for', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- Signatur
                <mfenced open="|" close="|">
                    [hva som helst]
                </mfenced> -->
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

    <xsl:template match="m:mrow" mode="verbal-matte">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="m:mn" mode="verbal-matte">
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
                <xsl:apply-templates mode="verbal-matte"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!--<xsl:template match="m:mi[matches(normalize-space(.),'^(sin|cos|tan)$')]" mode="verbal-matte">
        
        <xsl:text> </xsl:text>
        <xsl:value-of select="$funksjon"/>
        <xsl:text> til </xsl:text>
    </xsl:template>-->
    <xsl:template match="m:mi[contains(@mathvariant, 'bold')]" mode="verbal-matte" priority="5">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('vector', .)" />
        <xsl:text> </xsl:text>
        <xsl:next-match/>
    </xsl:template>

    <xsl:template
        match="m:mover[(count(child::element()) eq 2) and (local-name(child::element()[2]) eq 'mo') and (normalize-space(child::element()[2]) eq '&#8594;')]"
        mode="verbal-matte">
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('vector', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
    </xsl:template>

    <xsl:template match="m:mi[matches(normalize-space(.), '^\p{IsGreek}$')]" mode="verbal-matte">
        <xsl:variable name="uc" as="xs:integer" select="string-to-codepoints(normalize-space(.))"/>
        <!--
            Og vi dropper å annonsere at det gresk bokstav, for det er jo litt opplagt
            <xsl:text> gresk</xsl:text>-->
        <xsl:choose>
            <xsl:when test="$uc ge 945">
                <!-- Vi sier ikke ekstra informasjon om små greske bokstaver
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('liten', .)" />
                <xsl:text> </xsl:text> -->
            </xsl:when>
            <xsl:otherwise>
                <!-- men vi sier fra hvis de er store -->
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

    <xsl:template match="m:mi" mode="verbal-matte">
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
</xsl:stylesheet>
