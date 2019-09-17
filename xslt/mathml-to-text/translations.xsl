<?xml version="1.0" encoding="UTF-8"?>
    <xsl:stylesheet 
        xmlns="http://www.w3.org/1999/xhtml"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xpath-default-namespace="http://www.w3.org/1999/xhtml"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:m="http://www.w3.org/1998/Math/MathML"
        xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner"
        exclude-result-prefixes="#all"
        version="2.0">
    
    <!-- 
        (c) 2019 NLB
        
        Gaute Rønningen, 11.09.2019
        Jostein Austvik Jacobsen, 11.09.2019
    -->
    
    <!-- 
        hvordan bruke:
            <xsl:value-of select="fnk:translate('translate', .)"/>
    -->
    <xsl:function name="fnk:translate" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:param name="context" as="node()"/>
        
        <xsl:variable name="language" select="($context/ancestor-or-self::*/@xml:lang)[last()]"/>      
        <xsl:variable name="result" select="$dictionary/term[@name=$text]/translation[@lang=$language]/text()"/>
        <xsl:choose>
            <xsl:when test="not($result)">
                <xsl:message select="concat('Translation missing for: ', $text, ' (language=', $language, ')')"/>
                <xsl:value-of select="$text"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$dictionary/term[@name=$text]/translation[@lang=$language]/text()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:variable name="dictionary" as="element()">
        <dictionary>
            <!-- General terms -->
            <term name="unknown operator">
                <translation lang="en">unknown operator</translation>
                <translation lang="nb">ukjent operator</translation>
            </term>
            <term name="No template found">
                <translation lang="en">No template found for this:</translation>
                <translation lang="nb">Ingen mal for denne:</translation>
            </term>
            <term name="of">
                <translation lang="en">of</translation>
                <translation lang="nb">av</translation>
            </term>
            <term name="in">
                <translation lang="en">in</translation>
                <translation lang="nb">i</translation>
            </term>
            <term name="from">
                <translation lang="en">from</translation>
                <translation lang="nb">fra</translation>
            </term>
            <term name="to">
                <translation lang="en">to</translation>
                <translation lang="nb">til</translation>
            </term>
            <term name="and">
                <translation lang="en">and</translation>
                <translation lang="nb">og</translation>
            </term>
            <term name="when">
                <translation lang="en">when</translation>
                <translation lang="nb">når</translation>
            </term>
            <term name="formula">
                <translation lang="en">formula</translation>
                <translation lang="nb">formel</translation>
            </term>
            <term name="formula end">
                <translation lang="en">formula end</translation>
                <translation lang="nb">formel slutt</translation>
            </term>
            <term name="parenthesis">
                <translation lang="en">parenthesis</translation>
                <translation lang="nb">parentes</translation>
            </term>
            <term name="parenthesis end">
                <translation lang="en">parenthesis end</translation>
                <translation lang="nb">parentes slutt</translation>
            </term>
            <term name="small">
                <translation lang="en">small</translation>
                <translation lang="nb">liten</translation>
            </term>
            <term name="capital">
                <translation lang="en">capital</translation>
                <translation lang="nb">stor</translation>
            </term>
            <term name="exponent end">
                <translation lang="en">exponent end</translation>
                <translation lang="nb">eksponent slutt</translation>
            </term>
            <term name="the function">
                <translation lang="en">the function</translation>
                <translation lang="nb">funksjonen</translation>
            </term>
            <term name="unknown function">
                <translation lang="en">unknown function</translation>
                <translation lang="nb">ukjent funksjon</translation>
            </term>
            <term name="of the expression">
                <translation lang="en">of the expression</translation>
                <translation lang="nb">av uttrykket</translation>
            </term>
            <term name="the expression">
                <translation lang="en">the expression</translation>
                <translation lang="nb">uttrykket</translation>
            </term>
            <term name="expression end">
                <translation lang="en">expression end</translation>
                <translation lang="nb">uttrykk slutt</translation>
            </term>
            <term name="and at last">
                <translation lang="en">and at last</translation>
                <translation lang="nb">og til slutt</translation>
            </term>
            <term name="the faculty">
                <translation lang="en">the faculty</translation>
                <translation lang="nb">fakultet</translation>
            </term>
            <term name="vector">
                <translation lang="en">vector</translation>
                <translation lang="nb">vektor</translation>
            </term>
            <term name="left bracket">
                <translation lang="en">left bracket</translation>
                <translation lang="nb">venstre hakeparentes</translation>
            </term>
            <term name="right bracket">
                <translation lang="en">right bracket</translation>
                <translation lang="nb">høyre hakeparentes</translation>
            </term>
            <term name="with the lower index">
                <translation lang="en">with the lower index</translation>
                <translation lang="nb">med nedre indeks</translation>
            </term>
            
            <!-- Absolutes -->
            <term name="absolute value end">
                <translation lang="en">absolute value end</translation>
                <translation lang="nb">absoluttverdi slutt</translation>
            </term>
            <term name="the absolute value for the expression">
                <translation lang="en">the absolute value for the expression</translation>
                <translation lang="nb">absoluttverdien til uttrykket</translation>
            </term>
            <term name="the absolute value for">
                <translation lang="en">the absolute value for</translation>
                <translation lang="nb">absoluttverdien til</translation>
            </term>
            
            <!-- Table -->
            <term name="a matrix with">
                <translation lang="en">a matrix with</translation>
                <translation lang="nb">en matrise med</translation>
            </term>
            <term name="rows and with">
                <translation lang="en">rows and with</translation>
                <translation lang="nb">rader og med</translation>
            </term>
            <term name="column">
                <translation lang="en">column</translation>
                <translation lang="nb">kolonne</translation>
            </term>
            <term name="and the last column">
                <translation lang="en">and the last column</translation>
                <translation lang="nb">og siste kolonne</translation>
            </term>
            <term name="columns">
                <translation lang="en">columns</translation>
                <translation lang="nb">kolonner</translation>
            </term>
            <term name="row">
                <translation lang="en">row</translation>
                <translation lang="nb">rad</translation>
            </term>
            <term name="matrix end">
                <translation lang="en">matrix end</translation>
                <translation lang="nb">matrise slutt</translation>
            </term>
            
            <!-- Derivative -->
            <term name="the second derivative of the function">
                <translation lang="en">the second derivative of the function</translation>
                <translation lang="nb">den annenderiverte av funksjonen</translation>
            </term>
            <term name="the derivative of the function">
                <translation lang="en">the derivative of the function</translation>
                <translation lang="nb">den deriverte av funksjonen</translation>
            </term>
            <term name="the second derivative">
                <translation lang="en">the second derivative</translation>
                <translation lang="nb">annenderivert</translation>
            </term>
            <term name="the second derivative of">
                <translation lang="en">the second derivative of</translation>
                <translation lang="nb">den annenderiverte av</translation>
            </term>
            <term name="the derivative">
                <translation lang="en">the derivative</translation>
                <translation lang="nb">derivert</translation>
            </term>
            <term name="the derivative of">
                <translation lang="en">the derivative of</translation>
                <translation lang="nb">den deriverte av</translation>
            </term>
            
            <!-- Boundary values -->
            <term name="boundary value of">
                <translation lang="en">boundary value of</translation>
                <translation lang="nb">grenseverdien av</translation>
            </term>
            
            <!-- Raised -->
            <term name="raised to">
                <translation lang="en">raised to</translation>
                <translation lang="nb">opphøyd i</translation>
            </term>
            
            
            <!-- Square root -->
            <term name="square root of">
                <translation lang="en">square root of</translation>
                <translation lang="nb">kvadratroten av</translation>
            </term>
            <term name="square root end">
                <translation lang="en">square root end</translation>
                <translation lang="nb">kvadratrot slutt</translation>
            </term>
            
            <!-- N-root -->
            <term name="squared">
                <translation lang="en">squared</translation>
                <translation lang="nb">roten av</translation>
            </term>
            
            <!-- Fractions -->
            <term name="the fraction">
                <translation lang="en">the fraction</translation>
                <translation lang="nb">brøken</translation>
            </term>
            <term name="division with dividend">
                <translation lang="en">division with dividend</translation>
                <translation lang="nb">brøk med teller</translation>
            </term>
            <term name="and with divisor">
                <translation lang="en">and with divisor</translation>
                <translation lang="nb">og med nevner</translation>
            </term>
            
            <!-- Functions -->
            <term name="sine">
                <translation lang="en">sine</translation>
                <translation lang="nb">sinus</translation>
            </term>
            <term name="cosine">
                <translation lang="en">cosine</translation>
                <translation lang="nb">cosinus</translation>
            </term>
            <term name="tangent">
                <translation lang="en">tangent</translation>
                <translation lang="nb">tangens</translation>
            </term>
            <term name="arcus sine">
                <translation lang="en">arcus sine</translation>
                <translation lang="nb">arkus sinus</translation>
            </term>
            <term name="arcus cosine">
                <translation lang="en">arcus cosine</translation>
                <translation lang="nb">arkus cosinus</translation>
            </term>
            <term name="arcus tangent">
                <translation lang="en">arcus tangent</translation>
                <translation lang="nb">arkus tangens</translation>
            </term>
            <term name="hyperbolic sine">
                <translation lang="en">hyperbolic sine</translation>
                <translation lang="nb">hyperbolsk sinus</translation>
            </term>
            <term name="hyperbolic cosine">
                <translation lang="en">hyperbolic cosine</translation>
                <translation lang="nb">hyperbolsk cosinus</translation>
            </term>
            <term name="hyperbolic tangent">
                <translation lang="en">hyperbolic tangent</translation>
                <translation lang="nb">hyperbolsk tangens</translation>
            </term>
            <term name="cotangent">
                <translation lang="en">cotangent</translation>
                <translation lang="nb">cotangens</translation>
            </term>
            <term name="secant">
                <translation lang="en">secant</translation>
                <translation lang="nb">secans</translation>
            </term>
            <term name="cosecant">
                <translation lang="en">cosecant</translation>
                <translation lang="nb">cosecans</translation>
            </term>
            <term name="arcus cotangent">
                <translation lang="en">arcus cotangent</translation>
                <translation lang="nb">arkus cotangens</translation>
            </term>
            <term name="arcus secant">
                <translation lang="en">arcus secant</translation>
                <translation lang="nb">arkus secans</translation>
            </term>
            <term name="arcus cosecant">
                <translation lang="en">arcus cosecant</translation>
                <translation lang="nb">arkus cosecans</translation>
            </term>
            <term name="hyperbolic cotangent">
                <translation lang="en">hyperbolic cotangent</translation>
                <translation lang="nb">hyperbolsk cotangens</translation>
            </term>
            <term name="hyperbolic secant">
                <translation lang="en">hyperbolic secant</translation>
                <translation lang="nb">hyperbolsk secans</translation>
            </term>
            <term name="hyperbolic cosecant">
                <translation lang="en">hyperbolic cosecant</translation>
                <translation lang="nb">hyperbolsk cosecans</translation>
            </term>
            <term name="hyperbolic arcus sine">
                <translation lang="en">hyperbolic arcus sine</translation>
                <translation lang="nb">hyperbolsk arkus sinus</translation>
            </term>
            <term name="hyperbolic arcus cosine">
                <translation lang="en">hyperbolic arcus cosine</translation>
                <translation lang="nb">hyperbolsk arkus cosinus</translation>
            </term>
            <term name="hyperbolic arcus tangent">
                <translation lang="en">hyperbolic arcus tangent</translation>
                <translation lang="nb">hyperbolsk arkus tangens</translation>
            </term>
            <term name="hyperbolic arcus cotangent">
                <translation lang="en">hyperbolic arcus cotangent</translation>
                <translation lang="nb">hyperbolsk arkus cotangens</translation>
            </term>
            <term name="the natural logarithm">
                <translation lang="en">the natural logarithm</translation>
                <translation lang="nb">den naturlige logaritmen</translation>
            </term>
            <term name="unknown function">
                <translation lang="en">unknown function</translation>
                <translation lang="nb">ukjent funksjon</translation>
            </term>
            
            <!-- Operators -->
            <term name="plus">
                <translation lang="en">plus</translation>
                <translation lang="nb">pluss</translation>
            </term>
            <term name="minus">
                <translation lang="en">minus</translation>
                <translation lang="nb">minus</translation>
            </term>
            <term name="times">
                <translation lang="en">times</translation>
                <translation lang="nb">ganger</translation>
            </term>
            <term name="divided by">
                <translation lang="en">over</translation>
                <translation lang="nb">delt på</translation>
            </term>
            <term name="equals">
                <translation lang="en">equals</translation>
                <translation lang="nb">er lik</translation>
            </term>
            <term name="is greater or equal to">
                <translation lang="en">is greater or equal to</translation>
                <translation lang="nb">er større eller lik</translation>
            </term>
            <term name="et cetera">
                <translation lang="en">et cetera</translation>
                <translation lang="nb">og så videre</translation>
            </term>
            <term name="differ from">
                <translation lang="en">differ from</translation>
                <translation lang="nb">er forskjellig fra</translation>
            </term>
            <term name="is less than">
                <translation lang="en">is less than</translation>
                <translation lang="nb">er mindre enn</translation>
            </term>
            <term name="is much less than">
                <translation lang="en">is much less than</translation>
                <translation lang="nb">er mye mindre enn</translation>
            </term>
            <term name="is less than or equal to">
                <translation lang="en">is less than or equal to</translation>
                <translation lang="nb">er mindre eller lik</translation>
            </term>
            <term name="is greater than">
                <translation lang="en">is greater than</translation>
                <translation lang="nb">er større enn</translation>
            </term>
            <term name="is much greater than">
                <translation lang="en">is much greater than</translation>
                <translation lang="nb">er mye større enn</translation>
            </term>
            <term name="plus-minus">
                <translation lang="en">plus-minus</translation>
                <translation lang="nb">pluss minus</translation>
            </term>
            <term name="minus-plus">
                <translation lang="en">minus-plus</translation>
                <translation lang="nb">minus pluss</translation>
            </term>
            <term name="goes against">
                <translation lang="en">goes against</translation>
                <translation lang="nb">går mot</translation>
            </term>
            <term name="unlimited">
                <translation lang="en">unlimited</translation>
                <translation lang="nb">uendelig</translation>
            </term>
            <term name="the imaginary unit">
                <translation lang="en">the imaginary unit</translation>
                <translation lang="nb">den imaginære enhet</translation>
            </term>
            <term name="is equivalent of">
                <translation lang="en">is equivalent of</translation>
                <translation lang="nb">er ekvivalent med</translation>
            </term>
            
            <!-- Integrals -->
            <term name="unknown integral">
                <translation lang="en">unknown integral</translation>
                <translation lang="nb">ukjent integraltegn</translation>
            </term>
            <term name="integral">
                <translation lang="en">integral</translation>
                <translation lang="nb">integralet</translation>
            </term>
            <term name="integral of">
                <translation lang="en">integral of</translation>
                <translation lang="nb">integralet av</translation>
            </term>
            <term name="the double integral">
                <translation lang="en">the double integral</translation>
                <translation lang="nb">dobbeltintegralet</translation>
            </term>
            <term name="the double integral of">
                <translation lang="en">the double integral of</translation>
                <translation lang="nb">dobbeltintegralet av</translation>
            </term>
            <term name="the triple integral">
                <translation lang="en">the triple integralf</translation>
                <translation lang="nb">trippelintegralet</translation>
            </term>
            <term name="the triple integral of">
                <translation lang="en">the triple integral of</translation>
                <translation lang="nb">trippelintegralet av</translation>
            </term>
            <term name="the contour integral">
                <translation lang="en">the contour integral</translation>
                <translation lang="nb">kontur integralet</translation>
            </term>
            <term name="the contour integral of">
                <translation lang="en">the contour integral of</translation>
                <translation lang="nb">kontur integralet av</translation>
            </term>
            <term name="with respect to">
                <translation lang="en">with respect to</translation>
                <translation lang="nb">med hensyn på</translation>
            </term>
            
            <!-- Greek letters -->
            <term name="unknown greek letter">
                <translation lang="en">unknown greek letter</translation>
                <translation lang="nb">ukjent gresk bokstav</translation>
            </term>
            <term name="alpha">
                <translation lang="en">alpha</translation>
                <translation lang="nb">alfa</translation>
            </term>
            <term name="beta">
                <translation lang="en">beta</translation>
                <translation lang="nb">beta</translation>
            </term>
            <term name="gamma">
                <translation lang="en">gamma</translation>
                <translation lang="nb">gamma</translation>
            </term>
            <term name="delta">
                <translation lang="en">delta</translation>
                <translation lang="nb">delta</translation>
            </term>
            <term name="epsilon">
                <translation lang="en">epsilon</translation>
                <translation lang="nb">epsilon</translation>
            </term>
            <term name="pi">
                <translation lang="en">pi</translation>
                <translation lang="nb">pi</translation>
            </term>
            <term name="phi">
                <translation lang="en">phi</translation>
                <translation lang="nb">phi</translation>
            </term>
            <term name="omega">
                <translation lang="en">omega</translation>
                <translation lang="nb">omega</translation>
            </term>
            
            <!-- Numbers -->
            <term name="one">
                <translation lang="en">one</translation>
                <translation lang="nb">en</translation>
            </term>
            <term name="two">
                <translation lang="en">two</translation>
                <translation lang="nb">to</translation>
            </term>
            <term name="three">
                <translation lang="en">three</translation>
                <translation lang="nb">tre</translation>
            </term>
            <term name="four">
                <translation lang="en">four</translation>
                <translation lang="nb">fire</translation>
            </term>
            <term name="five">
                <translation lang="en">five</translation>
                <translation lang="nb">fem</translation>
            </term>
            <term name="six">
                <translation lang="en">six</translation>
                <translation lang="nb">seks</translation>
            </term>
            <term name="seven">
                <translation lang="en">seven</translation>
                <translation lang="nb">syv</translation>
            </term>
            <term name="eight">
                <translation lang="en">eight</translation>
                <translation lang="nb">åtte</translation>
            </term>
            <term name="nine">
                <translation lang="en">nine</translation>
                <translation lang="nb">ni</translation>
            </term>
            <term name="ten">
                <translation lang="en">ten</translation>
                <translation lang="nb">ti</translation>
            </term>
            
            <!-- Sort orders -->
            <term name="first">
                <translation lang="en">first</translation>
                <translation lang="nb">første</translation>
            </term>
            <term name="second">
                <translation lang="en">second</translation>
                <translation lang="nb">andre</translation>
            </term>
            <term name="third">
                <translation lang="en">third</translation>
                <translation lang="nb">tredje</translation>
            </term>
            <term name="fourth">
                <translation lang="en">fourth</translation>
                <translation lang="nb">fjerde</translation>
            </term>
            <term name="fifth">
                <translation lang="en">fifth</translation>
                <translation lang="nb">femte</translation>
            </term>
            <term name="sixth">
                <translation lang="en">sixth</translation>
                <translation lang="nb">sjette</translation>
            </term>
            <term name="seventh">
                <translation lang="en">seventh</translation>
                <translation lang="nb">sjuende</translation>
            </term>
            <term name="eighth">
                <translation lang="en">eighth</translation>
                <translation lang="nb">åttende</translation>
            </term>
            <term name="ninth">
                <translation lang="en">ninth</translation>
                <translation lang="nb">niende</translation>
            </term>
            <term name="tenth">
                <translation lang="en">tenth</translation>
                <translation lang="nb">tiende</translation>
            </term>
            
        </dictionary>
    </xsl:variable>
</xsl:stylesheet>