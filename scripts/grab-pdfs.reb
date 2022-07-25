rebol [
    File: %grab-pdfs.reb
    Name: Grab-PDFs
    Date: [25-Jan-2020 1-Jul-2021]
    Author: "Graham Chiu"
    Description: {
        Looks for the special authorities based on a list I provide.

        Download those ones, split the resulting download pdf into single
        pages and then convert each page to PNG, EPS.

        Editing this script and pushing it to GitHub triggers a workflow.  The
        final output of files of EPS, PDF and PNG are then available to be
        downloaded via GitHub artifacts:

        https://docs.github.com/en/actions/advanced-guides/storing-workflow-data-as-artifacts
    }
    Notes: {
      * Other related tools for this task are `pdfseparate` and `pdftops -eps`
        which may be useful if there are problems with GhostScript.
    }
]


=== LIST OF "WANTED" DRUGS WE ARE INTERESTED IN ===

; Check their page (pdfs) to see what other drugs are supported.  Comments are
; the SA numbers as of Oct 2021.  (Benzbromarone SA1537 is now gone)
;
wanted: [
    "Adalimumab"  ; SA2049
    "Etanercept"  ; SA2048
    "Teriparatide"  ; SA1139
    "Zoledronic acid inj 0.05 mg per ml, 100 ml"  ; SA1780
    "Tocilizumab"  ; SA2078
    "Secukinumab"  ; SA2044
    "Upadacitinib"  ; SA2079
]


=== URLS OF NEW ZEALAND PHARMAC RESOURCES ===

; Pharmac puts an index of all the Special authorities on this page
;
index-url: https://schedule.pharmac.govt.nz/SAForms.php

; and this is their download directory
;
base-url: join https://schedule.pharmac.govt.nz/ spread reduce [
    now/year "/" next form (100 + now/month) "/01/"
]
alternate-base-url: https://schedule.pharmac.govt.nz/latest/


=== PARSE WEB PAGE AND EXTRACT LINKS ===

; this is what we have to parse out .. we want the pdf name, and the drug name
; <td><a href='/latest/SA2102.pdf' target='_blank' title='SA2102 - 15 pages, 80 KB'>SA2102 [PDF]</a></td>
; <td><a href='/ScheduleOnline.php?osq=Adalimumab'>Adalimumab (Amgevita)</a></td>
;
; <td><a href='/latest/SA1847.pdf'>SA1847 - Adalimumab</a> (20 pages, 235 KB)</td>
;
; sample capture stored in the drugs block
;
;     drugs: [
;         "Benzbromarone" "SA1537.pdf"
;         "Teriparatide" "SA1139.pdf"
;         "Adalimumab" "SA1847.pdf"
;         "Etanercept" "SA1812.pdf"
;     ]

drugs: copy []

parse (to text! read index-url) [
    some [
        thru {<a href='/latest/}
        pdfname: across to {'}
        thru "/ScheduleOnline.php?osq="
        drugname: across to {'} (
            print ["In index:" drugname]
            if find wanted drugname [
                append/line drugs spread reduce [drugname pdfname]
            ]
        )
    ]
]


=== DOWNLOAD EACH PDF AND SAVE IT TO THE LOCAL FILESYSTEM ===

print "downloading pdfs"

for-each [drugname pdfname] drugs [
    location1: join base-url pdfname
    location2: join alternate-base-url pdfname

    dump location1
    print form type-of location1
    dump location2
    print form type-of location2

    url: if exists? location1 [ location1 ] else [ location2 ]
    print [drugname ":" url]

    write to file! pdfname read url
    print ["Success with" pdfname]
]


=== CONVERT EACH PDF TO PNG AND EPS ===

print "converting pdfs to png and eps"

for-each [drugname pdfname] drugs [
    ; get the SAnnnn part of the pdf name
    root: parse pdfname [between <here> ".pdf"]

    ; delete all extraneous png and eps files
    attempt [rm *.eps]
    attempt [rm *.png]

    print ["Processing" drugname "as" pdfname]

    ; Convert to individual pages of .PNG and .EPS using ghostscript ("gs")
    ;
    ; The `%02d` is a printf()-style format instruction, asking it to make the
    ; integer page number (%d) represented as 2 digits (%02d)

    call [
        gs -sDEVICE=pngmono -o (join root "-%02d.png") -r600 (pdfname)
    ]

    call [
        gs -sDEVICE=eps2write -sPAPERSIZE=a4
            -o (join root "-%02d.eps") (pdfname)
    ]
]

print "Finished job"
