<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
        xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
        queryBinding="xslt2">
    
    <title>Regler for OPF-metadata</title>
    
    <ns prefix="opf" uri="http://www.idpf.org/2007/opf"/>
    <ns prefix="dc" uri="http://purl.org/dc/elements/1.1/"/>
    
    <pattern>
        <title>Boknummer</title>
        <rule context="opf:metadata">
            <assert test="count(dc:identifier[not(@refines)]) = 1">Det må være nøyaktig ett boknummer (dc:identifier).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Språk</title>
        <rule context="opf:metadata">
            <assert test="count(dc:language) gt 0">Det må være minst ett språk (dc:language).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Tittel</title>
        <rule context="opf:metadata">
            <assert test="count(dc:title) gt 0">Tittel må være definert (dc:title).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Forlag for åndsverk</title>
        <rule context="opf:metadata">
            <assert test="count(opf:meta[@property='dc:publisher.original']) gt 0">Originalforlag må være definert (dc:publisher.original).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Forlag for utgave</title>
        <rule context="opf:metadata[dc:format/text() != 'EPUB']">
            <assert test="count(dc:publisher) gt 0">Forlag må være definert (dc:publisher).</assert>
        </rule>
    </pattern>
    
</schema>
