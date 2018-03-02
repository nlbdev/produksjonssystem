<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
        xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
        queryBinding="xslt2">
    
    <title>Regler for DTBook</title>
    
    <ns prefix="dtbook" uri="http://www.daisy.org/z3986/2005/dtbook/"/>
    
    <pattern>
        <title>Boknummer</title>
        <rule context="dtbook:head">
            <assert test="count(dtbook:meta[@name='dc:Identifier']) = 1">Det må være nøyaktig ett boknummer (dc:Identifier).</assert>
            <assert test="dtbook:meta[@name='dc:Identifier']/@content = dtbook:meta[@name='dtb:uid']/@content">dc:Identifier og dtb:uid må være like.</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Språk</title>
        <rule context="dtbook:head">
            <assert test="count(dtbook:meta[@name='dc:Language']) gt 0">Det må være minst ett språk (dc:Language).</assert>
            <report test="count(dtbook:meta[@name='dc:Language' and string-length(@content) != 2]) gt 0">Språkkoder må kun bruke to bokstaver.</report>
        </rule>
    </pattern>
    
    <pattern>
        <title>Tittel</title>
        <rule context="dtbook:head">
            <assert test="count(dtbook:meta[@name='dc:Title']) = 1">Det må være nøyaktig én tittel (dc:Title) Fant <value-of select="count(dtbook:meta[@name='dc:Title'])"/>.</assert>
        </rule>
    </pattern>
    
    <!--<pattern>
        <title>Forlag</title>
        <rule context="dtbook:head">
            <assert test="count(dtbook:meta[@name='dc:Publisher']) = 1">Det må være nøyaktig ett forlag (dc:Publisher). Fant <value-of select="count(dtbook:meta[@name='dc:Publisher'])"/>.</assert>
        </rule>
    </pattern>-->
    
    <pattern>
        <title>Utgivelsesdato</title>
        <rule context="dtbook:head">
            <assert test="count(dtbook:meta[@name='dc:Date']) = 1">Utgivelsesdato må være gitt nøyaktig en gang (dc:Date).</assert>
            <assert test="dtbook:meta[@name='dc:Date']/matches(@content,'^\d\d\d\d-\d\d-\d\d$')">Utgivelsesdato må følge formatet YYYY-MM-DD (år-måned-dag).</assert>
        </rule>
    </pattern>
    
</schema>
