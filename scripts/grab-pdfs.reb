rebol [
    File: %grab-pdfs.reb
    Name: Grab-PDFs
    Date: [25-Jan-2020 1-Jul-2021]
    Author: "Graham Chiu"
    Notes: {
        Looks for the special authorities based on a list I provide.

        Download those ones, split the resulting download pdf into single
        pages and then convert each page to PNG, EPS.

        Editing this script and pushing it to GitHub triggers a workflow.  The
        final output of files of EPS, PDF and PNG are then available to be
        downloaded via GitHub artifacts:

        https://docs.github.com/en/actions/advanced-guides/storing-workflow-data-as-artifacts
    }
]


=== LIST OF "WANTED" DRUGS WE ARE INTERESTED IN ===

; Check their page (pdfs) to see what other drugs are supported
;
; As of August 2020 the pages are:
;
;     Adalimumab SA1950
;     Etanercept SA1949
;     Teriparatide SA1139
;     Zolendronic Acid SA1780
;     Benzbromarone SA1537 xxx gone
;     Tocilizumab 1858
;     Secukinumab 2044
;     Upadacitinib
;
wanted: [
    "Adalimumab"
    "Etanercept"
    "Teriparatide"
    "Zoledronic acid inj 0.05 mg per ml, 100 ml"
    "Tocilizumab"
    "Secukinumab"
    "Upadacitinib"
]


=== URLS OF NEW ZEALAND PHARMAC RESOURCES ===

; Pharmac puts an index of all the Special authorities on this page
;
pdfs: https://schedule.pharmac.govt.nz/SAForms.php

; and this is their download directory
;
base: to url! unspaced [https://schedule.pharmac.govt.nz/ now/year "/" next form (100 + now/month) "/01/"]
alternate-base: https://schedule.pharmac.govt.nz/latest/


=== PARSE WEB PAGE AND EXTRACT LINKS ===

; this is what we have to parse out .. we want the pdf name, and the drug name
;
; <td><a href='/latest/SA1847.pdf'>SA1847 - Adalimumab</a> (20 pages, 235 KB)</td>
;
; sample capture stored in the drugs block
;
;     drugs: [
;         ["Benzbromarone" "SA1537.pdf"]
;         ["Teriparatide" "SA1139.pdf"]
;         ["Adalimumab" "SA1847.pdf"]
;         ["Etanercept" "SA1812.pdf"]
;     ]

data: to text! read pdfs

drugs: copy []

parse data [
    some [
        thru {<a href='/latest/} copy sa to {'} thru " - " copy name to </a> (
            dump name ;; debug
            if find wanted name [
                append/only drugs reduce [name sa]
            ]
        )
    ]
]


=== DOWNLOAD EACH PDF AND SAVE IT TO THE LOCAL FILESYSTEM ===

print "downloading pdfs"

for-each pair drugs [
    print unspaced [ pair/1 ": " base pair/2]
    location1: to url! join base pair/2
    location2: join alternate-base pair/2
    file: if exists? location1 [ location1 ] else [ location2 ]
    attempt [
        ; the reads seem to be affected by timeouts so let's skip errors
        write to file! pair/2 read file
        print spaced ["Success with" pair/1]
    ]
]


=== CONVERT EACH PDF TO PNG AND EPS ===

print "converting pdfs to png and eps"

for-each pair drugs [
    ; get the SAnnnn part of the pdf name
    pdf: pair/2
    root: copy/part pdf find pdf %.pdf

    ; delete all extraneous png and eps files
    attempt [rm *.eps]
    attempt [rm *.png]

    print spaced ["Processing" pair/1 "as" pdf]

    ; convert to png using ghostscript
    ;
    script: unspaced ["gs -sDEVICE=pngmono -o " root "-%02d.png -r600 " pdf]
    call script

    ; !!! This was commented out
    ;
    comment [
        script: unspaced ["gs sDEVICE=eps2write -sPAPERSIZE=a4 -o " root "-%02d.eps " pdf]
    ]

    ; split into separate pdfs eg. SA1234-01.pdf
    ;
    call unspaced ["pdfseparate " pdf space root "-%02d.pdf"]

    ; now to convert each of the pdfs into eps
    n: 1
    forever [
        if exists? filename: to file! unspaced [root "-" next form 100 + n %.pdf] [
            call unspaced ["pdftops -eps " filename]
        ] else [
            break
        ]
        n: me + 1
    ]
    call script
]

print "Finished job"

quit
