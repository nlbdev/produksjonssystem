<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" exclude-result-prefixes="xs m fnk"
    version="2.0">

    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 21.01.2019
    -->
    

    <xsl:template match="m:semantics" mode="verbal-matte">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="m:mspace | m:annotation" mode="verbal-matte" />
    
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
                <xsl:text> i </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <!-- standardform -->
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> opphøyd i </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
                <xsl:text> eksponent slutt </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="m:msup[child::*[2] eq '2']" mode="verbal-matte">
        <!-- Kan gjøre denne strengere ved å kreve at andre barn skal være 'mn' -->

        <xsl:apply-templates select="child::*[1]" mode="#current"/>
        <xsl:text> i annen </xsl:text>
    </xsl:template>

    <xsl:template match="m:mfrac" mode="verbal-matte">
        <xsl:choose>
            <!-- Hvis alle (det vil begge) barna er enten mi- eller mn-elementer, med passe enkelt innhold, presenter det enkelt ... -->
            <xsl:when
                test="
                    every $e in child::element()
                        satisfies
                        (
                        (
                        (local-name($e) eq 'mi') and
                        matches($e, '^[a-z]$')
                        )
                        or
                        (
                        (local-name($e) eq 'mn') and
                        matches($e, '^\d{1,3}$')
                        )
                        )">
                <xsl:text> brøken </xsl:text>
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> delt på </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- ... og hvis ikke, full pakke: -->
                <xsl:text> brøk med teller </xsl:text>
                <xsl:apply-templates select="child::*[1]" mode="#current"/>
                <xsl:text> og med nevner </xsl:text>
                <xsl:apply-templates select="child::*[2]" mode="#current"/>
                <xsl:text> brøk slutt </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="m:mfrac[@bevelled eq 'true']" mode="verbal-matte">
        <!--<xsl:text> brøk med teller </xsl:text>-->
        <xsl:apply-templates select="child::*[1]" mode="#current"/>
        <xsl:text> delt på </xsl:text>
        <xsl:apply-templates select="child::*[2]" mode="#current"/>
        <!--<xsl:text> brøk slutt </xsl:text>-->
    </xsl:template>

    <xsl:template match="m:annotation-xml[@encoding eq 'MathML-Content']" mode="#all">
        <!-- ignorer dette -->
    </xsl:template>

    <xsl:template match="m:mtable" mode="verbal-matte">
        <xsl:text> en matrise med </xsl:text>
        <xsl:value-of select="fnk:tall(count(m:mtr))"/>
        <xsl:text>
            rader og med 
        </xsl:text>
        <xsl:value-of select="fnk:tall(count(m:mtr[1]/m:mtd))"/>
        <xsl:text> kolonner: </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> matrise slutt</xsl:text>
    </xsl:template>

    <xsl:template match="m:mtr" mode="verbal-matte">
        <xsl:if test="count(following-sibling::m:mtr) eq 0">
            <xsl:text> og til slutt </xsl:text>
        </xsl:if>
        <xsl:value-of select="fnk:ordenstall(1 + count(preceding-sibling::m:mtr))"/>
        <xsl:text> rad: </xsl:text>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="m:mtd" mode="verbal-matte">
        <xsl:choose>
            <xsl:when test="count(following-sibling::m:mtd) eq 0">
                <xsl:text> og siste kolonne: </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="fnk:ordenstall(1 + count(preceding-sibling::m:mtd))"/>
                <xsl:text> kolonne: </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates mode="verbal-matte"/>
        <xsl:text> </xsl:text>
    </xsl:template>

    <xsl:template match="m:mo" mode="verbal-matte">
        <xsl:variable name="operator" as="xs:string" select="normalize-space(.)"/>
        <xsl:choose>
            <xsl:when test="matches($operator,'^(,|\.)$')">
                <!-- Her brukes altså mo elementet for å ivareta et skilletegn. Dette er lov, se https://www.w3.org/TR/MathML3/chapter3.html#presm.mo
                    Litt usikker på hva som er lurt, men i første omgang så kan vi bare beholde dette skilletegnet.
                    Et alternativ kan være å ignorere det.
                -->
                <xsl:value-of select="$operator"/>
            </xsl:when>
            <xsl:when test="$operator eq '...'">
                <xsl:text> og så videre </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '+'">
                <xsl:text> pluss </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '='">
                <xsl:text> er lik </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8800;'">
                <xsl:text> er forskjellig fra </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&lt;'">
                <xsl:text> er mindre enn </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x226A;'">
                <xsl:text> er mye mindre enn </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x2264;'">
                <xsl:text> er mindre eller lik </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&gt;'">
                <xsl:text> er større enn </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x226B;'">
                <xsl:text> er mye større enn </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#x2265;'">
                <xsl:text> er større eller lik </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '-'">
                <xsl:text> minus </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq ':'">
                <xsl:text> delt på </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#177;'">
                <xsl:text> pluss minus </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8723;'">
                <xsl:text> minus pluss </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8901;'">
                <xsl:text> ganger </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8594;'">
                <xsl:text> går mot </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8743;'">
                <xsl:text> og </xsl:text>
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
                        <xsl:text> ganger </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>


            </xsl:when>


            <xsl:when test="$operator eq '&#8747;'">
                <xsl:text> integralet av </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8748;'">
                <xsl:text> dobbeltintegralet av </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8749;'">
                <xsl:text> trippelintegralet av </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8750;'">
                <xsl:text> konturintegralet av </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '&#8518;'">
                <xsl:text> med hensyn på </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq '['">
                <xsl:text> venstre hakeparentes </xsl:text>
            </xsl:when>
            <xsl:when test="$operator eq ']'">
                <xsl:text> høyre hakeparentes </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>Ukjent operator: <xsl:value-of select="."/></xsl:message>
                <xsl:text> ukjent operator </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template
        match="m:mo[normalize-space(.) eq '!'][exists(preceding-sibling::element()) and matches(local-name(preceding-sibling::element()[1]), '^(mi|mn)$')]"
        mode="verbal-matte">
        <!-- Krever altså at foregående element før <mo>!</mo> finnes, og at det er mi eller mn -->
        <xsl:text> fakultet </xsl:text>
    </xsl:template>
    <xsl:template match="m:mfenced" mode="verbal-matte">
        <xsl:text> parentes </xsl:text>
        <xsl:apply-templates mode="#current"/>
        <xsl:text> parentes slutt </xsl:text>
    </xsl:template>

    <xsl:template match="m:mfenced[@open = '|' and @close eq '|']" mode="verbal-matte">
        <xsl:choose>
            <xsl:when test="(count(child::element()) eq 1) and exists(m:mi)">
                <!-- Signatur
            <mfenced open="|" close="|">
                <mi>[hva som helst</mi>
            </mfenced> -->
                <xsl:text> absoluttverdien til </xsl:text>
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
                <xsl:text> absoluttverdien til </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- Signatur
                <mfenced open="|" close="|">
                    [hva som helst]
                </mfenced> -->
                <xsl:text> absoluttverdien til uttrykket </xsl:text>
                <xsl:apply-templates mode="#current"/>
                <xsl:text> absoluttverdi slutt </xsl:text>
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
                    <xsl:text> minus </xsl:text>
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
    <xsl:template match="m:mi[contains(@mathvariant,'bold')]" mode="verbal-matte" priority="5">
        <xsl:text> vektor </xsl:text>
        <xsl:next-match></xsl:next-match>
    </xsl:template>
    
    <xsl:template match="m:mover[(count(child::element()) eq 2) and (local-name(child::element()[2]) eq 'mo') and (normalize-space(child::element()[2]) eq '&#8594;')]" mode="verbal-matte">
        <xsl:text> vektor </xsl:text>
        <xsl:apply-templates select="child::element()[1]" mode="#current"></xsl:apply-templates>
    </xsl:template>

    <xsl:template match="m:mi[matches(normalize-space(.), '^\p{IsGreek}$')]" mode="verbal-matte">
        <xsl:variable name="uc" as="xs:integer" select="string-to-codepoints(normalize-space(.))"/>
        <!--
            Og vi dropper å annonsere at det gresk bokstav, for det er jo litt opplagt
            <xsl:text> gresk</xsl:text>-->
        <xsl:choose>
            <xsl:when test="$uc ge 945">
                <!-- Vi sier ikke ekstra informasjon om små greske bokstaver
                <xsl:text> liten </xsl:text> -->
            </xsl:when>
            <xsl:otherwise>
                <!-- men vi sier fra hvis de er store -->
                <xsl:text> stor</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:choose>
            <xsl:when test="($uc eq 945) or ($uc eq 913)">
                <xsl:text> alfa</xsl:text>
            </xsl:when>
            <xsl:when test="($uc eq 946) or ($uc eq 914)">
                <xsl:text> beta</xsl:text>
            </xsl:when>
            <xsl:when test="($uc eq 947) or ($uc eq 915)">
                <xsl:text> gamma</xsl:text>
            </xsl:when>
            <xsl:when test="($uc eq 948) or ($uc eq 916)">
                <xsl:text> delta</xsl:text>
            </xsl:when>
            <xsl:when test="($uc eq 949) or ($uc eq 917)">
                <xsl:text> epsilon</xsl:text>
            </xsl:when>
            <!-- TODO: Andre små greske bokstaver -->
            <xsl:when test="($uc eq 960) or ($uc eq 928)">
                <xsl:text> pi</xsl:text>
            </xsl:when>
            <!-- TODO: Andre små greske bokstaver -->
            <xsl:when test="($uc eq 966) or ($uc eq 934)or ($uc eq 981)">
                <xsl:text> fi</xsl:text>
            </xsl:when>
            <!-- TODO: Andre små greske bokstaver -->
            <xsl:when test="($uc eq 969) or ($uc eq 937)">
                <xsl:text> omega</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>ukjent greks bokstav: <xsl:value-of select="$uc"/></xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="m:mi" mode="verbal-matte">
        <xsl:variable name="operator" as="xs:string" select="normalize-space(.)"/>
        <xsl:choose>
            <xsl:when test="$operator eq '&#8734;'">
                <xsl:text> uendelig </xsl:text>
            </xsl:when>
            <xsl:when test="matches($operator, '^\p{Lu}$')">
                <xsl:text> stor </xsl:text>
                <xsl:value-of select="lower-case(.)"/>
            </xsl:when>
            <xsl:when test="$operator eq '&#8520;'">
                <xsl:text> den imaginære enhet </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
