<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
        xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
        queryBinding="xslt2">
    
    <title>Regler for HTML-metadata</title>
    
    <ns prefix="html" uri="http://www.w3.org/1999/xhtml"/>
    
    <pattern>
        <title>Boknummer, ISBN og ISSN</title>
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
            <assert test="count(html:meta[@name='dc:publisher.location.original']) gt 0">Utgivelsessted for originalen må være definert (dc:publisher.location.original).</assert>
            <assert test="count(html:meta[@name='dc:date.issued.original']) gt 0">Utgivelsesår for originalen må være definert (dc:date.issued.original).</assert>
            <assert test="count(html:meta[@name='schema:bookEdition.original']) gt 0">Utgave for originalen må være definert (schema:bookEdition.original).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Forlag for utgave</title>
        <rule context="html:head[html:meta[@name='dc:format']/@content != 'EPUB']">
            <assert test="count(html:meta[@name='dc:publisher']) gt 0">Forlag må være definert (dc:publisher).</assert>
            <assert test="count(html:meta[@name='dc:publisher.location']) gt 0">Utgivelsessted må være definert (dc:publisher.location).</assert>
            <assert test="count(html:meta[@name='dc:date.issued']) gt 0">Utgivelsesår må være definert (dc:date.issued).</assert>
            <assert test="count(html:meta[@name='schema:bookEdition']) gt 0">Utgave må være definert (schema:bookEdition).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Oversatt utgave</title>
        <rule context="html:head[html:meta[@name='dc:format']/@content != 'EPUB' and html:meta/@name = ('dc:language.original', 'dc:title.original', 'dc:contributor.translator')]">
            <assert test="html:meta[@name='dc:language.original']">Originalspråk må være definert for oversatte utgaver (dc:language.original).</assert>
            <assert test="html:meta[@name='dc:title.original']">Originaltittel må være definert for oversatte utgaver (dc:title.original).</assert>
            <assert test="html:meta[@name='dc:contributor.translator']">Oversetter må være definert for oversatte utgaver (dc:contributor.translator).</assert>
        </rule>
    </pattern>
    
</schema>
