<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
        xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
        queryBinding="xslt2">
    
    <title>Regler for HTML-metadata</title>
    
    <ns prefix="html" uri="http://www.w3.org/1999/xhtml"/>
    
    <pattern>
        <title>Boknummer</title>
        <rule context="html:head">
            <assert test="count(html:meta[@name='dc:identifier']) = 1">Det må være nøyaktig ett boknummer (dc:identifier).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Språk</title>
        <rule context="html:head">
            <assert test="count(html:meta[@name='dc:language']) gt 0">Det må være minst ett språk (dc:language).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Tittel</title>
        <rule context="html:head">
            <assert test="count(html:title) = 1">Det må være nøyaktig én tittel (title).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Forlag for åndsverk</title>
        <rule context="html:head">
            <assert test="count(html:meta[@name='dc:publisher.original']) gt 0">Originalforlag må være definert (dc:publisher.original).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Forlag for utgave</title>
        <rule context="html:head[html:meta[@name='dc:format']/@content != 'EPUB']">
            <assert test="count(html:meta[@name='dc:publisher']) gt 0">Forlag må være definert (dc:publisher).</assert>
        </rule>
    </pattern>
    
</schema>
