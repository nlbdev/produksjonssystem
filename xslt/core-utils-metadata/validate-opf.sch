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
            <assert test="count(opf:meta[not(@refines)][@property='dc:publisher.original']) gt 0">Originalforlag må være definert (dc:publisher.original).</assert>
            <assert test="count(opf:meta[not(@refines)][@property='dc:publisher.location.original']) gt 0">Utgivelsessted for originalen må være definert (dc:publisher.location.original).</assert>
            <assert test="count(opf:meta[not(@refines)][@property='dc:date.issued.original']) gt 0">Utgivelsesår for originalen må være definert (dc:date.issued.original).</assert>
            <assert test="count(opf:meta[not(@refines)][@property='schema:bookEdition.original']) gt 0">Utgave for originalen må være definert (schema:bookEdition.original).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Forlag for utgave</title>
        <rule context="opf:metadata[dc:format/text() != 'EPUB']">
            <assert test="count(dc:publisher) gt 0">Forlag må være definert (dc:publisher).</assert>
            <assert test="count(opf:meta[not(@refines)][@property='dc:publisher.location']) gt 0">Utgivelsessted må være definert (dc:publisher.location).</assert>
            <assert test="count(opf:meta[not(@refines)][@property='dc:date.issued']) gt 0">Utgivelsesår må være definert (dc:date.issued).</assert>
            <assert test="count(opf:meta[not(@refines)][@property='schema:bookEdition']) gt 0">Utgave må være definert (schema:bookEdition).</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Oversatt utgave</title>
        <rule context="opf:metadata[dc:format/text() != 'EPUB' and opf:meta[not(@refines)]/@property = ('dc:language.original', 'dc:title.original', 'dc:contributor.translator')]">
            <assert test="opf:meta[not(@refines)][@property='dc:language.original']">Originalspråk må være definert for oversatte utgaver (dc:language.original).</assert>
            <assert test="opf:meta[not(@refines)][@property='dc:title.original']">Originaltittel må være definert for oversatte utgaver (dc:title.original).</assert>
            <assert test="opf:meta[not(@refines)][@property='dc:contributor.translator']">Oversetter må være definert for oversatte utgaver (dc:contributor.translator).</assert>
        </rule>
    </pattern>
    
</schema>
