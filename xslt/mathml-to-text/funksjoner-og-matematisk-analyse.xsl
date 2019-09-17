<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" exclude-result-prefixes="xs m fnk"
    version="2.0">

    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 21.01.2019
        Gaute Rønningen, 09.09.2019
    -->
    
    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    <xsl:import href="utilities.xsl"/>
    
    <!-- Kvadratrot -->
    <xsl:template match="m:msqrt" mode="verbal-matte">
        <!-- Vi har to former:
            * standardform "kvadratroten av ... kvadratrot slutt"
            * kortform "roten av ..."
            Den siste brukes når argumentet for funksjonen er et tall med tre sifre eller færre, eller nå det er et symbol med betgnelse a-z
        -->
        <xsl:choose>
            <xsl:when
                test="
                    count(child::element()) eq 1
                    and
                    (
                    (
                    (local-name(child::element()[1]) eq 'mn')
                    and
                    matches(normalize-space(.), '^\d{1,3}$')
                    )
                    or
                    (
                    (local-name(child::element()[1]) eq 'mi')
                    and
                    matches(normalize-space(.), '^[a-z]$')
                    )
                    )">
                <!-- kortform -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('squared', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- stadandarform -->
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

    <!-- n-rot -->
    <xsl:template match="m:mroot[matches(normalize-space(child::element()[2]), '^(\d|[a-z])$')]"
        mode="verbal-matte">
        <xsl:choose>
            <xsl:when test="matches(normalize-space(child::element()[2]), '^\d$')">
                <!-- et tall -->
                <xsl:value-of select="normalize-space(child::element()[2])"/>
                <xsl:text>. </xsl:text>
                <xsl:value-of select="fnk:translate('squared', .)"/>
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <!-- et tall -->
                <xsl:value-of select="normalize-space(child::element()[2])"/>
                <xsl:text>-</xsl:text>
                <xsl:value-of select="fnk:translate('squared', .)"/>
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
    </xsl:template>

    <!-- Trigonometriske, og andre, funksjoner
        Merk:   &#8289; = &ApplyFunction;
    -->
    <xsl:template
        match="
            m:mrow[
            (count(child::element()) eq 3) (: mrow må ha tre barn, og det er ingen krav til det tredje barnet :)
            and (local-name(child::element()[1]) eq 'mi') (: første barn nå være mi :)
            and matches(normalize-space(child::element()[1]), '^(sin|cos|tan|arcsin|arccos|arctan|sinh|cosh|tanh|cot|sec|csc|cosec|arccot|arcsec|arccsc|arccosec|coth|sech|csch|cosech|arsinh|arcosh|artanh|arcoth|ln)$') (: og må inneholde et kjent funksjonsnavn, så her utvider vi etter hvert :)
            and (local-name(child::element()[2]) eq 'mo') (: andre barn må være mo :)
            and (normalize-space(child::element()[2]) eq '&#8289;') (: som inneholder ApplyFunction :)
            ]"
        mode="verbal-matte">
        <!-- Signatur
            <mrow>
                <mi>[funksjon[</mi>
                <mo>&ApplyFunction;</mo>    ( eller <mo>&af;</mo>
                <mi>, <mn>, <mfenced>, <mrow> eller lignende
            </mrow>
            
            Altså:
                * Alltid mrow med tre barn
                * Alltid et mi-element med et kjent funksjonsnavn
                * Alltid et mo-element som bare skal inneholde &ApplyFunction;
                * alltid et tredje element som representerer argumentet til funksjon. Verbal representasjon forenkles kanskje avhengig av dette elementet
        -->
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
            <xsl:when
                test="
                    matches(local-name(child::element()[3]), '^(mn|mi)$') (: vi har et tall eller et symbol (håper jeg) som argument for funksjonen ... :)
                    or
                    (
                    (local-name(child::element()[3]) eq 'mfenced') (: ... eller vi har en parentes ... :)
                    and
                    (count(m:mfenced/m:mrow) eq 1) (: som bare inneholder ett uttrykk :)
                    )
                    ">
                <!-- ... og da trenger vi ikke å informere om start og slutt på argumentet -->
                <xsl:apply-templates select="child::element()[3]" mode="verbal-matte"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the expression', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::element()[3]" mode="verbal-matte"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('expression end', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


    <!-- Funksjonen f(x)  
        Merk:   &#8289; = &ApplyFunction;
    -->
    <xsl:template
        match="
            m:mrow[
            (count(child::element()) eq 3) (: tre barn av mrow :)
            and (local-name(child::element()[1]) eq 'mi') (: første barn er mi :)
            and (local-name(child::element()[2]) eq 'mo') (: andre barn er mo ... :)
            and (local-name(child::element()[3]) eq 'mfenced') (: tredje barn er mfenced :)
            and (matches(normalize-space(m:mi), '^[a-z]$', 'i') or matches(normalize-space(m:mi), '^\p{IsGreek}$')) (: første barn er én bokstav i området a til z (eller A-Z), typisk er selvfølgelig f, g, h etc, men kan jo ha v(t) og lignende, eller en gresk bokstav  :)
            and (normalize-space(m:mo) eq '&#8289;') (: og ... inneholder ApplyFunction :)
            ]"
        mode="verbal-matte">
        <!-- Signatur:
            
            <mrow>
                <mi>[én bokstav i området a-z]</mi>
                <mo>&ApplyFunction;</mo>
                <mfenced>
                    [hva som helst]
                </mfenced>
            </mrow>
        -->

        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the function', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mi" mode="#current"/>

        <xsl:call-template name="presenter-funksjonsargumentene"/>

    </xsl:template>

    <!-- Grenseverdi  
        Merk:   &#8289; = &ApplyFunction;
    -->
    <xsl:template
        match="
            m:mrow[
            (local-name(child::element()[1]) eq 'munder') (: første barn av mrow skal være munder :)
            and (local-name(child::element()[2]) eq 'mo') (: andre barn være mo :)
            and (normalize-space(child::element()[2]) eq '&#8289;') (: og dette barnet skal bare inneholde ApplyFunction :)
            and (local-name(m:munder[1]/child::element()[1]) eq 'mo') (: første barn av første munder skal være mo :)
            and (normalize-space(m:munder[1]/m:mo[1]) eq 'lim') (: og dette barnet skal inneholde 'lim' og intet annet :)
            ]"
        mode="verbal-matte">
        <!-- Signatur:
           <mrow>
                <munder>
                    <mo>lim</mo>
                    [ett element som representerer et matematisk uttrykk, for eksempel]
                    <mrow>
                        <mi>x</mi>
                        <mo>&rarr;</mo>
                        <mn>0</mn>
                    </mrow>
                </munder>
                <mo>&ApplyFunction;</mo>
                [ett element som representerer et matematisk uttrykk, for eksempel]
                <mfrac>
                    <mn>1</mn>
                    <mi>x</mi>
                </mfrac>
                
            </mrow>
        -->


        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('boundary value of', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[3]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('when', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:munder[1]/child::element()[2]" mode="#current"/>
    </xsl:template>

    <!-- Førstederiverte f'(x) og annenderiverte f''(x) 
        Merk:   &#8289; = &ApplyFunction;
                &#8242; = &prime;   (')
                &#8243; = &Prime;   ('')
    -->

    <!-- TODO: Denne må utvides til å håndtere greske tegn, store bokstave for funksjoner etc -->
    <xsl:template
        match="
            m:mrow[
            (count(child::element()) eq 3) (: tre barn av mrow :)
            and (local-name(child::element()[1]) eq 'msup') (: første barn er msup :)
            and (local-name(child::element()[2]) eq 'mo') (: andre barn er mo ... :)
            and (local-name(child::element()[3]) eq 'mfenced') (: tredje barn er mfenced :)
            and (local-name(m:msup/child::element()[1]) eq 'mi') (: første barn av msup er mi ... :)
            and (matches(m:msup/m:mi, '^[a-z]$')) (: og dette mi-elmentet inneholder én bokstav i området a til z, typisk er selvfølgelig f, g, h etc, men kan jo ha v(t) og lignende :)
            and (local-name(m:msup/child::element()[2]) eq 'mo') (: andre barn av msup er mo ... :)
            and ((normalize-space(m:msup/m:mo) eq '&#8242;') or (normalize-space(m:msup/m:mo) eq '&#8243;')) (: og ... og dette barnet inneholder bare prime eller Prime :)
            and (normalize-space(m:mo) eq '&#8289;') (: og ... inneholder ApplyFunction :)
            ]"
        mode="verbal-matte">
        <!-- Signatur:
            <mrow>
                <msup>
                    <mi>[én bokstav i området a-z]</mi>
                    <mo>&Prime;</mo>
                </msup>
                <mo>&ApplyFunction;</mo>
                <mfenced>
                    <mi>x</mi>
                </mfenced>
            </mrow>
        -->
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

        <xsl:call-template name="presenter-funksjonsargumentene"/>
        <!--        <xsl:text> av </xsl:text>
        <xsl:apply-templates select="m:mfenced/*" mode="verbal-matte"/>-->
    </xsl:template>


    <!-- Uttrykk på formen (...)' og (...)'' 
        Merk:   &#8242; = &prime;   (')
                &#8243; = &Prime;   ('')
    -->

    <xsl:template
        match="
            m:msup[
            (local-name(child::element()[1]) eq 'mfenced') (: første barn av msup er mfenced ... :)
            and (local-name(child::element()[2]) eq 'mo') (: andre barn av msup er mfenced ... :)
            and ((normalize-space(m:mo) eq '&#8242;') or (normalize-space(m:mo) eq '&#8243;')) (: og ... inneholder prime eller Prime :)
            ]"
        mode="verbal-matte">
        <!-- Signatur:
                <msup>
                    <mfenced>
                        [hva som helst]
                    </mfenced>
                    <mo>&Prime;</mo>
                </msup>
        -->
        <xsl:apply-templates select="m:mfenced" mode="verbal-matte"/>
        <xsl:choose>
            <xsl:when test="normalize-space(m:mo) eq '&#8243;'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the second derivative', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('the derivative', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Uttrykk på formen d ... / d ..., altså "den (første)deriverte av ... med hensyn på ..." -->
    <xsl:template
        match="
            m:mfrac[
            (count(child::element()) eq 2) (: to barn av mfrac :)
            and (every $c in child::element()
                satisfies local-name($c) eq 'mrow') (: og begge barna er mrow :)
            and (every $c in m:mrow
                satisfies ((local-name($c/child::element()[1]) eq 'mo') and (normalize-space($c/child::element()[1]) eq '&#x02146;'))) (: og for begge mrow gjelder at første barn av mrow er mo og inneholder DifferentialD ... :)
            and (count(m:mrow[2]/child::element()) eq 2) (: bare to barn i 'nevneren' :)
            and (local-name(m:mrow[2]/child::element()[2]) eq 'mi') (: vi vet allerede at det første barnet er mo, og vi krever også at det andre barnet er mi :)
            and (matches(m:mrow[2]/m:mi, '^[a-z]$')) (: og dette mi-elementet må inneholde én bokstav i området a til z :)
            ]"
        mode="verbal-matte">

        <!-- NB: Denne er ikke veldig robust. Det er ikke kontroll på hva telleren ellers består av, så dette kan blir rart. -->

        <!--
        Signatur:
            <mfrac>
                <mrow>
                    <mo>&DifferentialD;</mo>
                    [hva som helst, for eksempel det følgende]
                    <mrow>
                        <mi>f</mi>
                        <mo>&ApplyFunction;</mo>
                        <mfenced>
                            <mi>x</mi>
                        </mfenced>
                    </mrow>
                </mrow>
                <mrow>
                    <mo>&dd;</mo>
                    <mi>[én bokstav i området a-z]</mi>
                </mrow>
            </mfrac>
    -->
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the derivative of', .)" />
        <xsl:text> </xsl:text>
        <!-- prosesser alt i telleren som kommer etter &#x02146; -->
        <xsl:apply-templates
            select="m:mrow[1]/child::element()[preceding-sibling::m:mo eq '&#x02146;']"
            mode="verbal-matte"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with respect to', .)" />
        <xsl:text> </xsl:text>
        <!-- prosesser alt i nevneren som kommer etter &#x02146; -->
        <xsl:apply-templates select="m:mrow[2]/m:mi" mode="verbal-matte"/>
        <xsl:text>, </xsl:text>
    </xsl:template>

    <!-- Uttrykk på formen d^2 ... / d ...^2, altså "den annenderiverte av ... med hensyn på ..." -->
    <xsl:template
        match="
            m:mfrac[
            (count(child::element()) eq 2) (: to barn av mfrac :)
            and (every $c in child::element()
                satisfies local-name($c) eq 'mrow') (: og begge barna er mrow :)
            (: vi stiller krav til 'telleren' :)
            and (local-name(m:mrow[1]/child::element()[1]) eq 'msup') (: første mrow  (altså 'telleren') har msup som første barn :)
            and (local-name(m:mrow[1]/m:msup[1]/child::element()[1]) eq 'mo') (: og dette msup-elementet har igjen mo som første barn :)
            and (local-name(m:mrow[1]/m:msup[1]/child::element()[2]) eq 'mn') (: og dette msup-elementet har igjen mn som andre barn :)
            and (normalize-space(m:mrow[1]/m:msup[1]/m:mo) eq '&#x02146;') (: og dette mo-elementet består av DifferentialD :)
            and (normalize-space(m:mrow[1]/m:msup[1]/m:mn) eq '2') (: og mn-elementet består av tallet to :)
            (: og så stiller vi krav til 'nevneren' :)
            and (count(m:mrow[2]/child::element()) eq 2) (: andre mrow skal bare inneholde to barn :)
            and (local-name(m:mrow[2]/child::element()[1]) eq 'mo') (: det første barnet skal være et mo-element :)
            and (local-name(m:mrow[2]/child::element()[2]) eq 'msup') (: det andre barnet skal være msup :)
            and (normalize-space(m:mrow[2]/m:mo) eq '&#x02146;') (: og dette mo-elementet består av DifferentialD :)
            and (local-name(m:mrow[2]/m:msup/child::element()[1]) eq 'mi') (: og msup-elementet må ha mi som første barn :)
            and (local-name(m:mrow[2]/m:msup/child::element()[2]) eq 'mn') (: og msup-elementet må ha mn som første barn :)
            and (matches(m:mrow[2]/m:msup/m:mi, '^[a-z]$')) (: og dette mi-elementet må inneholde én bokstav i området a til z :)
            and (normalize-space(m:mrow[2]/m:msup/m:mn) eq '2') (: og mn-elementet består av tallet to :)
            ]"
        mode="verbal-matte">
        <!-- NB: Denne er ikke veldig robust. Det er ikke kontroll på hva telleren ellers består av, så dette kan blir rart. -->

        <!--
        Signatur:
            <mfrac>
                <mrow>
                    <msup>
                        <mo>&DifferentialD;</mo>
                        <mn>2</mn>
                    </msup>
                    [hva som helst, for eksempel det følgende]
                    <mrow>
                        <mi>f</mi>
                        <mo>&ApplyFunction;</mo>
                        <mfenced>
                            <mi>x</mi>
                        </mfenced>
                    </mrow>
                </mrow>
                <mrow>
                    <mo>&dd;</mo>
                    <msup>
                        <mi>[én bokstav i området a-z]</mi>
                        <mn>2</mn>
                    </msup>
                </mrow>
            </mfrac>
    -->
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('the second derivative of', .)" />
        <xsl:text> </xsl:text>
        <!-- prosesser alt i telleren som kommer etter det første msup-elementet, altså har posisjon to eller mer-->
        <xsl:apply-templates select="m:mrow[1]/child::element()[position() ge 2]"
            mode="verbal-matte"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with respect to', .)" />
        <xsl:text> </xsl:text>
        <!-- prosesser alt i nevneren som kommer etter &#x02146; -->
        <xsl:apply-templates select="m:mrow[2]/m:msup/m:mi" mode="verbal-matte"/>
        <xsl:text>, </xsl:text>
    </xsl:template>

    <!--             and (matches(normalize-space(m:munderover/m:mo[1]),'^&#8747;$') (: og dette barnet består av bare int :)
 -->


    <!-- Integralet fra ... til ... av ... med hensyn på ...
        Merk:   &#8747; = &int; (vanlig integraltegn)    
    -->
    <xsl:template
        match="
            m:mrow[
            (count(child::element()) eq 3) (: tre barn av mrow :)
            and (local-name(child::element()[1]) eq 'munderover') (: første er munderover :)
            (: andre kan være hva som helst :)
            and (local-name(child::element()[3]) eq 'mrow') (: og det siste er mrow :)
            (: vi legger inn krav til munderover-elementet :)
            and (local-name(m:munderover/child::element()[1]) eq 'mo') (:  første barn av munderover er mo:)
            and matches(normalize-space(m:munderover/m:mo[1]),'^(&#8747;|&#8748;|&#8749;|&#8750;)$') (: og dette barnet består av bare int :)
            (: vi legger inn krav til det siste (og kanskje det eneste) mrow-elementet :)
            and (count(m:mrow[last()]/child::element()) eq 2) (: to barn i siste mrow-elementet :)
            and (local-name(m:mrow[last()]/child::element()[1]) eq 'mo') (:  første barn av siste mrow er mo:)
            and (normalize-space(m:mrow[last()]/m:mo[1]) eq '&#8518;') (: og dette mo-elementet består av DifferentialD :)
            and (local-name(m:mrow[last()]/child::element()[2]) eq 'mi') (:  andre barn av siste mrow er mi:)
            and matches(normalize-space(m:mrow[last()]/m:mi), '^[a-z]$') (: og dette mi-elementet må inneholde én bokstav i området a til z :)
            ]"
        mode="verbal-matte">
        <!-- Signatur:
            <mrow>
                <munderover>
                    <mo>&int;</mo>
                    [nedre grense]
                    [øvre grense]
                </munderover>
                [hva som helst, for eksempel]
                <mrow>
                    <mi>f</mi>
                    <mo>&ApplyFunction;</mo>
                    <mfenced>
                        <mi>t</mi>
                    </mfenced>
                </mrow>
                <mrow>
                    <mo>&dd;</mo>
                    <mi>[én bokstav i området a-z]</mi>
                </mrow>
            </mrow>
        -->
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
        <xsl:apply-templates select="m:munderover/child::element()[2]" mode="verbal-matte"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('to', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:munderover/child::element()[3]" mode="verbal-matte"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('of', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[2]" mode="verbal-matte"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with respect to', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mrow[last()]/child::element()[2]" mode="verbal-matte"/>
        <xsl:text>, </xsl:text>
    </xsl:template>


    <xsl:template name="presenter-funksjonsargumentene">
        <!-- Analyser argumentene til funksjonen -->
        <xsl:choose>
            <xsl:when
                test="(count(m:mfenced/element()) eq 1) and matches(local-name(m:mfenced/element()), '^(mi|mn)$')">
                <!-- Det er ett enkelt argument, og det er et tall eller en variabel -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="m:mfenced/*" mode="verbal-matte"/>
            </xsl:when>
            <xsl:when
                test="
                    (count(m:mfenced/element()) gt 1) and (every $a in m:mfenced/element()
                        satisfies matches(local-name($a), '^(mi|mn)$'))">
                <!-- Det er flere argumenter, men alle er tall er variabler -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of', .)" />
                <xsl:text> </xsl:text>
                <xsl:for-each select="m:mfenced/element()">
                    <xsl:apply-templates select="." mode="verbal-matte"/>
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
                <!-- Det er ett argument, men det er komplekst -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of the expression', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="m:mfenced/*" mode="verbal-matte"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('expression end', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <!-- Det er ikke godt å si hva dette er, men vi behandler det som komplekst -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('of the expression', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="m:mfenced/*" mode="verbal-matte"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('expression end', .)" />
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


</xsl:stylesheet>
