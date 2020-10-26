<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
		xmlns:k="k"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all" 
                version="2.0">
    
    <xsl:output indent="no" method="xhtml" include-content-type="no"/>
    
    <xsl:variable name="urls" select="document('url-fix.xml')/*/*" as="element()*"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- fix URLs with spaces -->
    <xsl:template match="html:a[@href]" xpath-default-namespace="">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @href"/>
            <xsl:variable name="fix" select="($urls[(original, original-unquoted)/text() = normalize-space(current()/@href)])[1]/fixed/text()" as="xs:string?"/>
            <xsl:attribute name="href" select="if ($fix) then $fix else @href"/>
            <xsl:choose>
                <xsl:when test="boolean($fix) and count(node()) = 1 and normalize-space(text()) = normalize-space(@href)">
                    <xsl:value-of select="$fix"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="node()"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="$fix">
                <xsl:message select="concat('Lenken &quot;', @href, '&quot; ble erstattet med &quot;', $fix, '&quot;.')"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="html:meta[@name='dc:identifier']">
        <xsl:variable name="test" select="starts-with(@content, 'TEST')" as="xs:boolean"/>
        <xsl:variable name="identifier" select="replace(@content, '[^\d]', '')" as="xs:string"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="content" select="concat(if ($test) then 'TEST' else '', $identifier)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="html:meta[@name='dtb:uid']"/>

  <xsl:template match="span[@class = 'asciimath']">
    <xsl:variable name="ascii" select="."/>
    <span>
      <xsl:attribute name="class">
        <xsl:value-of select="./@class"/>
      </xsl:attribute>
      <xsl:variable name="ascii" select="k:ascii2Blind($ascii)"/>
      <xsl:if test="ancestor::table and ancestor::section[@class = 'task'] and matches($ascii, '^[A-Z]\s=$')">
        <xsl:value-of select="$ascii"/>
        <xsl:text>....</xsl:text>
      </xsl:if>
      <xsl:if test="not(ancestor::table and ancestor::section[@class = 'task'] and matches($ascii, '^[A-Z]\s=$'))">
        <xsl:value-of select="$ascii"/>
      </xsl:if>
    </span>
    <xsl:variable name="nextNode" select="following-sibling::*[1]"/>
    <!-- xsl:message><xsl:value-of select="$nextNode/name()" /></xsl:message -->
    <xsl:variable name="followingText" select="following::text()[1]"/>
    <!-- xsl:value-of select="$nextNode" / -->
    <xsl:if test="$nextNode[@class = 'asciimath'] and (replace($followingText, '\s+', '') = '')">
      <!-- [@class = 'asciimath']" -->
      <xsl:text>, </xsl:text>
    </xsl:if>
  </xsl:template>
  <xsl:template match="span[@class = 'asciimath' and ((ancestor::div[@class = 'cas']) or (ancestor::table[@class = 'spreadsheet']) or (ancestor::figure[@class = 'image calculator']))]" priority="1">
    <span>
      <xsl:attribute name="class">
        <xsl:value-of select="./@class"/>
      </xsl:attribute>
      <xsl:variable name="a" as="xs:string" select="replace(., '`(.*)`', '$1')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, '\*\*', '*')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, '//', '/')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, 'rarr', '-&gt;')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, ' (\+|-|\*|/|:|=) ', '$1')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, ' ?~~ ?', '~~')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, ' ?&quot; ?', '')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, '^kr(\S)', 'kr $1')"/>
      <xsl:variable name="a" as="xs:string" select="replace($a, '(\d)\.(\d)', '$1,$2')"/>
      <!-- xsl:variable name="a" as="xs:string" select="replace($a, ' =', '=')"/ -->
      <xsl:variable name="a" as="xs:string" select="replace($a, '^ =', '=')"/>
      <xsl:if test="ancestor::div[@class = 'cas']">
        <xsl:value-of select="replace($a, '^[1-3] ?(\d|\(|[a-zA-Z])', '$1')"/>
      </xsl:if>
      <xsl:if test="not(ancestor::div[@class = 'cas'])">
        <xsl:value-of select="$a"/>
      </xsl:if>
    </span>
  </xsl:template>

 <xsl:function name="k:ascii2Blind">
    <xsl:param name="asciimathInn" as="xs:string"/>
    <xsl:variable name="asciimathInn" as="xs:string" select="replace($asciimathInn, '`(.*)`', '$1')"/>
    <!-- xsl:variable name="asciimathInn" as="xs:string" select="replace($asciimathInn, 'ulul\((.*)\)', '$1===')"/>
    <xsl:variable name="asciimathInn" as="xs:string" select="replace($asciimathInn, 'ulul\(?(.*)\)?', '$1===')"/ -->
    <xsl:variable name="asciimathInn" as="xs:string" select="replace($asciimathInn, 'ulul\((.*)\)', '$1')"/>
    <xsl:variable name="asciimathInn" as="xs:string" select="replace($asciimathInn, 'ulul\(?(.*)\)?', '$1')"/>
    <xsl:variable name="asciimathInn" as="xs:string" select="
        replace($asciimathInn, 'ul\((.*?)\)', '$1
    ')"/>
    <!-- fill in-tasks. three - as four . -->
    <xsl:variable name="asciimathInn" as="xs:string" select="replace($asciimathInn, '---', '....')"/>
    <xsl:variable name="fragmenter" as="xs:string*">
      <!-- Vi skal ikke gjøre noe med det som er mellom to anførselstegn -->
      <xsl:for-each select="tokenize($asciimathInn, &quot;&quot;&quot;&quot;)">
        <xsl:choose>
          <xsl:when test="position() mod 2 eq 1">
            <xsl:variable name="a" as="xs:string" select="replace(., ' = *', ' =')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '^ =', '=')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '&lt;= *', '&lt;=')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '~~ ', '~~')"/>
            <!-- fill in blanks, remove parentheses -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '\(\.{4}\)', '....')"/>
            <!-- inches written as double '' ( &#39;, &#x27; &apos;), replace with ", &quot; or &#x22; or &#34; -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '\(([0-9]*)''''\)', '$1&quot;')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '''''', '&quot;')"/>
            <!-- replace double // with single /-->
            <xsl:variable name="a" as="xs:string" select="replace($a, '//', '/')"/>
            <!-- intervals -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '(\[[0-9a-z\^\.,]{1,10}?),\s([0-9a-z\^\.,]{1,10}?)〉', '$1, $2[')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '〈([0-9a-z\^\.,]{1,10}?),\s([0-9a-z\^\.,]{1,10}?\])', ']$1, $2')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '〈([0-9a-z\^\.,]{1,10}?),\s([0-9a-z\^\.,]{1,10}?)〉', ']$1, $2[')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, ' xx ', ' * ')"/>
            <!-- div 5/2x or 4/3`p as 5/2 *x and (-(5)/(2)) as -5/2 -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '/(\d+)([a-zA-Z])', '/$1 *$2')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '/\((\d+)\)([a-zA-Z])', '/$1 *$2')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '/\((\d+)\)\)', '/$1)')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '-\((\d+)\)/', '-$1/')"/>
            <!-- 5/123( as 5/123 *( -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '/(\d+)\(', '/$1 *(')"/>
            <!-- ?/x2 as ?/x *2 -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '/([a-zA-Z])(\d+)', '/$1 *$2')"/>
            <!-- 2^4x as 2^4 *x -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '\^(\d+)([a-z])', '^$1 *$2')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '\^-(\d+)([a-z])', '^-$1 *$2')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '\^-(\d+)\(', '^-$1 *(')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '\^(\d+)\(', '^$1 *(')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, ' \+ ', ' +')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, ' - ', ' -')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, ' \* ', ' *')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, ' : ', ' :')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '‰', '%%')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, ' %', '%')"/>
            <!-- logic, elements -->
            <xsl:variable name="a" as="xs:string" select="replace($a, ' in ', ' `e ')"/>
            <!-- 2^(1,4) as 2^1,4 -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '\^\((\d+\.\d+)\)', '^$1')"/>
            <!-- degrees ^@ as ° -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '\^@', '°')"/>
            <!-- roots -->
            <xsl:variable name="a" as="xs:string" select="replace($a, 'sqrt', '¨')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, 'root\((.*?)\)(\(.*?\))', '^$1¨$2')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, 'root(.{1,7}?)(\(.*?\))', '^$1¨$2')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '([^\d]|^)\^(.{1,7}?)¨\((\d*?|[a-z])\)', '$1^$2¨$3')"/>
            <!-- decimal seperator -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '(.*?)(\d+)\.(\d+)(.*?)', '$1$2,$3$4')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '_(\d+)([a-zA-Z])', '_$1 *$2')"/>
            <!-- subnotation -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '_', '\\')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, 'epsilon', '`e')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, 'pi', '`p')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, 'lambda', '`l')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, '/(\d+)`', '/$1 *`')"/>
            <!-- union, ... Do this after select="replace($a,'_','\\')" -->
            <xsl:variable name="a" as="xs:string" select="replace($a, ' uu ', ' _u ')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, ' nn ', ' _s ')"/>
            <xsl:variable name="a" as="xs:string" select="replace($a, 'bar([A-Z])', '§-$1')"/>
            <!-- &gt; og &lt; -->
            <xsl:variable name="a" as="xs:string" select="replace($a, ' (&gt;|&lt;) ', ' $1')"/>
            <!-- | +-*/: \d -->
            <xsl:variable name="a" as="xs:string" select="replace($a, '\| (\+|\-|\*|/|:)(\d+)$', '&#160;&#160;$1$1$2')"/>
            <xsl:value-of select="$a"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- Lå opprinnelig mellom anførselstegn. Beholdes som det var, men uten anførselstegnene -->
            <xsl:value-of select="." separator=""/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="c" as="xs:string" select="string-join($fragmenter, '')"/>
    <xsl:variable name="c" as="xs:string" select="k:numberSeparator($c)"/>
    <xsl:variable name="c" as="xs:string" select="k:bigFraction($c)"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ';=', '; =')"/>
    <!-- non breakable space -->
    <xsl:variable name="c" as="xs:string" select="replace($c, ' \*', '&#160;*')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ' \+', '&#160;+')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ' -', '&#160;-')"/>
    <!-- &#x2011;')"/ -->
    <xsl:variable name="c" as="xs:string" select="replace($c, ' / ', '&#160;/&#160;')"/>
    <!-- xsl:variable name="c" as="xs:string" select="replace($c,' = ',' =')"/ -->
    <xsl:variable name="c" as="xs:string" select="replace($c, ' \* ', '&#160;*')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ' \+ ', '&#160;+')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ' - ', '&#160;-')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ' - ', '&#160;-')"/>
    <!-- insert space in expressions with text -->
    <!-- xsl:variable name="c" as="xs:string" select="replace($c,' =([a-zA-ZÆØÅæøå]{4,})','&#160;= $1')"/ -->
    <xsl:variable name="c" as="xs:string" select="replace($c, ' =([a-zA-ZÆØÅæøå]{4,})', ' = $1')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '&#160;\*([a-zA-ZÆØÅæøå]{4,})', '&#160;*&#160;$1')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '&#160;\+([a-zA-ZÆØÅæøå]{4,})', '&#160;+&#160;$1')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '&#160;-([a-zA-ZÆØÅæøå]{4,})', '&#160;-&#160;$1')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '&#160;-([a-zA-ZÆØÅæøå]{4,})', '&#160;-&#160;$1')"/>
    <!-- same as above -->
    <xsl:variable name="c" as="xs:string" select="replace($c, '([a-zA-ZÆØÅæøå]{4,})/([a-zA-ZÆØÅæøå]{4,})', '$1 / $2')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '(\d)/([a-zA-ZÆØÅæøå]{4,})', '$1/ $2')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '([a-zA-ZÆØÅæøå]{4,})/(\d)', '$1 /$2')"/>
    <!-- remove double space -->
    <xsl:variable name="c" as="xs:string" select="replace($c, '[\s&#160;]{2}', '&#160;')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '&#160;(\*{2})', '&#160;&#160;$1')"/>
    <!-- non-breaking hyphen -->
    <!-- xsl:variable name="c" as="xs:string" select="replace($c, '-', '&#8209;')"/ -->
    <!-- all space as regular space -->
    <xsl:variable name="c" as="xs:string" select="replace($c, '&#160;', ' ')"/>
    <xsl:if test="string-length($c) &lt; 33">
      <!-- all space as non-breaking -->
      <!-- xsl:value-of select="replace($c, ' ', '&#160;')"/ -->
      <xsl:value-of select="$c"/>
    </xsl:if>
    <xsl:if test="not(string-length($c) &lt; 33)">
      <xsl:value-of select="replace($c, '&#160;=', ' =')"/>
    </xsl:if>
  </xsl:function>

  <xsl:function name="k:bigFraction">
    <xsl:param name="input" as="xs:string"/>
    <xsl:variable name="fragmenter" as="xs:string*">
      <xsl:for-each select="tokenize($input, '=')">
        <xsl:choose>
          <xsl:when test="matches(., '/')">
            <!-- (a b)/(c d) ikke ^ -->
            <xsl:variable name="fraction" as="xs:string" select="replace(., '([^\^]|^)\(([^()]* [^()]*)*\)/\(([^()]* [^()]*)*\)([^\^]|$)', '$1;$2 / $3;$4')"/>
            <!-- (a b)/c(^...)? -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)\(([^()]*\s[^()]*)\)/(-?\d+([,.\d])*|-?[a-zA-Z])(\^(-?\d+([,.\d])*|-?[a-zA-Z]))?', '$1;$2 / $3$5;')"/>
            <!-- (a b)^.../c(^...)? -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)\(([^()]* [^()]*)\)(\^(-?\d+([,.\d])*|-?[a-zA-Z]))/(-?\d+([,.\d])*|-?[a-zA-Z])(\^(-?\d+([,.\d])*|-?[a-zA-Z]))?', '$1;$2$3 / $6$8;')"/>
            <!-- (a(d()) b)^.../c(^...)? -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+)\)/(-?\d+([,.\d])*|-?[a-zA-Z])(\^(-?\d+([,.\d])*|-?[a-zA-Z]))?', '$1;$2 / $5$7;')"/>
            <!-- a/(b c) not ^ -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)(\d+([,.\d])*|[a-zA-Z])(\^(-?\d+([,.\d])*|-?[a-zA-Z]))?/(\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()])+)\))([^\^]|$)', '$1;$2 / $8;')"/>
            <!-- (a (() )  b)^c/(d e)^f -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)(\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+)\)(\^(-?\d+([,.\d])*|-?[a-zA-Z])))/(\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()])+)\)(\^(-?\d+([,.\d])*|-?[a-zA-Z])))', '$1;$2 / $9;')"/>
            <!-- (*)/(*) -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+)\)/\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()])+)\)($|[^\^])', '$1;$2 / $5;$8')"/>
            <!-- (*)/*^?? -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+ (\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+)\)/(\d+([,.\d])*(\^(-?\d+([,.\d])*|-?[a-z]))?|[a-z](\^(-?\d+([,.\d])*|-?[a-z]))?)', '$1;$2 / $5;')"/>
            <!-- */(*) -->
            <!-- xsl:variable name="fraction" as="xs:string" select="replace($fraction, '(\d+([,.\d])*?(\^(\d+([,.\d])*|[a-z]))?|[a-z](\^(\d+([,.\d])*|[a-z]))?)/\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+) ((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+)\)(\^(\d+([,.\d])*|[a-z]))?', ';$1 / $9;KVILE3')"/ -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '(\d+([,.\d])*?(\^(-?\d+([,.\d])*|-?[a-z]))?|[a-z](\^(-?\d+([,.\d])*|-?[a-z]))?)/\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+) ((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+)\)', ';$1 / $9;')"/>
            <!-- (a (() ) b)(^..)?/(c d)^e -->
            <xsl:variable name="fraction" as="xs:string" select="replace($fraction, '([^\^]|^)(\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()]*)+)\)(\^(-?\d+([,.\d])*|-?[a-zA-Z]))?)/(\(((\([^()]*\)|\((\([^()]*\)|[^()])*\)|[^()])+)\)(\^(-?\d+([,.\d])*|-?[a-zA-Z])))', '$1;$3 / $9;')"/>
            <xsl:value-of select="$fraction"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="."/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="return" as="xs:string" select="string-join($fragmenter, '=')"/>
    <xsl:value-of select="$return"/>
  </xsl:function>
    
  <xsl:function name="k:numberSeparator">
    <xsl:param name="c" as="xs:string"/>
    <!-- decimal separator -->
    <xsl:variable name="c" as="xs:string" select="replace($c, ',(\d{3})(\d{2,})', ',$1.$2')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ',(\d{3})(.\d{3})(\d+)', ',$1$2.$3')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ',(\d{3})(.\d{3})(.\d{3})(\d+)', ',$1$2$3.$4')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, ',(\d{3})(.\d{3})(.\d{3})(.\d{3})(\d+)', ',$1$2$3$4.$5')"/>
    <!-- thousand separator -->
    <!-- xsl:variable name="c" as="xs:string" select="replace($c, '(\d{5,})', string(format-number(number('$1'), '#.###', 'euro')))" / -->
    <xsl:variable name="c" as="xs:string" select="replace($c, '([^,]|^)(\d{1,3})(\d{3})(\d{3})(\d{3})(\d{3})(\d{3})(\D|$)', '$1$2.$3.$4.$5.$6.$7$8')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '([^,]|^)(\d{1,3})(\d{3})(\d{3})(\d{3})(\d{3})(\D|$)', '$1$2.$3.$4.$5.$6$7')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '([^,]|^)(\d{1,3})(\d{3})(\d{3})(\d{3})(\D|$)', '$1$2.$3.$4.$5$6')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '([^,]|^)(\d{1,3})(\d{3})(\d{3})(\D|$)', '$1$2.$3.$4$5')"/>
    <xsl:variable name="c" as="xs:string" select="replace($c, '([^,]|^)(\d{2,3})(\d{3})(\D|$)', '$1$2.$3$4')"/>
    <xsl:value-of select="$c"/>
  </xsl:function>
</xsl:stylesheet>
