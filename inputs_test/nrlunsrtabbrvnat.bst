%% File: `nrlunsrtabbrvnat.bst'
%%
%% Unsorted, Abbreviated bibliography names
%% requires the natbib package
%%
%% A modification of `abbrvnat.bst` `unsrtnat.bst'
%% version 2019-08-27
%% NRL changes by Peter Mignerey, Code 7163, 13 April 2012
%%   - changed lines are tagged with: pcm13apr12
%%   - replaced periods with commas except for the last one
%%   - added quotes around journal titles
%%   - moved the period inside the close quote
%%   - made journal names roman font instead of italic
%%   - made journal volume number bold face
%%   - added parentheses around journal dates
%%   - added parentheses around book publishers
%%   - removed the period before open parentheses
%%   - added a few journal macros
%%   - added a new BibTeX entry for footnotes called "notes"
%%       that requires a KEY to sort, and whatever NOTE you wish to include.
%%
%% BibTeX is a postfix, lifo stack (reverse Polish) language. 
%% Hence it works in strange ways.
%% If you do not understand what that means,
%% you probably do not want to attempt editing this file.
%% see: Oren Patashnik, "BibTeXing," Feb. 8, 1988, chap.5
%% (Patashnik wrote BibTeX)
%%
%% Some uncommon bib entries may not appear as desired
%% because I am unsure of their format.
%%
%% File: `unsrtnat.bst'
%% A modification of `unsrt.bst' for use with natbib package
%%
%% Copyright 1993-2007 Patrick W Daly
%% Max-Planck-Institut f\"ur Sonnensystemforschung
%% Max-Planck-Str. 2
%% D-37191 Katlenburg-Lindau
%% Germany
%% E-mail: daly@mps.mpg.de
%%
%% This program can be redistributed and/or modified under the terms
%% of the LaTeX Project Public License Distributed from CTAN
%% archives in directory macros/latex/base/lppl.txt; either
%% version 1 of the License, or any later version.
 %
 % Version and source file information:
 % \ProvidesFile{natbst.mbs}[2007/11/26 1.93 (PWD)]
 %
 % BibTeX `plainnat' family
 %   version 0.99b for BibTeX versions 0.99a or later,
 %   for LaTeX versions 2.09 and 2e.
 %
 % For use with the `natbib.sty' package; emulates the corresponding
 %   member of the `plain' family, but with author-year citations.
 %
 % With version 6.0 of `natbib.sty', it may also be used for numerical
 %   citations, while retaining the commands \citeauthor, \citefullauthor,
 %   and \citeyear to print the corresponding information.
 %
 % For version 7.0 of `natbib.sty', the KEY field replaces missing
 %   authors/editors, and the date is left blank in \bibitem.
 %
 % Includes field EID for the sequence/citation number of electronic journals
 %  which is used instead of page numbers.
 %
 % Includes fields ISBN and ISSN.
 %
 % Includes field URL for Internet addresses.
 %
 % Includes field DOI for Digital Object Idenfifiers.
 %
 % Works best with the url.sty package of Donald Arseneau.
 %
 % Works with identical authors and year are further sorted by
 %    title text, as in the standard plain.bst etc.

ENTRY
  { address
    author
    booktitle
    chapter
    doi
    eid
    edition
    editor
    howpublished
    institution
    isbn
    issn
    journal
    key
    month
    note
    number
    organization
    pages
    publisher
    school
    series
    title
    type
    url
    volume
    year
  }
  {}
  { label extra.label sort.label short.list }

INTEGERS { output.state before.all mid.sentence after.sentence after.block }

FUNCTION {init.state.consts}
{ #0 'before.all :=
  #1 'mid.sentence :=
  #2 'after.sentence :=
  #3 'after.block :=
}

STRINGS { s t }

FUNCTION {add.period}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ "." * }
if$ }

FUNCTION {add.comma}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ "," * }
if$ }

FUNCTION {add.colon}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ ":" * }
if$ }

FUNCTION {add.openquote}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ "``" swap$ * }
if$ }

FUNCTION {add.closequote}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ "''" * }
if$ }

FUNCTION {add.openparen}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ "(" swap$ * }
if$ }

FUNCTION {add.closeparen}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ ")" * }
if$ }

FUNCTION {add.openbf}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ "{\bf " swap$ * }
if$ }

FUNCTION {add.closebf}	% pcm13apr12
{ duplicate$ empty$
'skip$
{ "}" * }
if$ }

FUNCTION {output.nonnull}
{ 's :=
  output.state mid.sentence =
    { ", " * write$ }
    { output.state after.block =
        {
	  add.comma write$		% pcm13apr12
          newline$
          "\newblock " write$
        }
        { output.state before.all =
            'write$
            { add.comma " " * write$ }	% pcm13apr12
          if$
        }
      if$
      mid.sentence 'output.state :=
    }
  if$
  s
}

FUNCTION {nocomma.output.nonnull}	% pcm13apr12
{ 's :=
  output.state mid.sentence =
    { " " * write$ }			% pcm13apr12
    { output.state after.block =
        {
	  " " * write$		% pcm13apr12
          newline$
          "\newblock " write$
        }
        { output.state before.all =
            'write$
            { " " * write$ }	% pcm13apr12
          if$
        }
      if$
      mid.sentence 'output.state :=
    }
  if$
  s
}

FUNCTION {nocomma.closequote.output.nonnull}	% pcm13apr12
{ 's :=
  output.state mid.sentence =
    { add.closequote " " * write$ }			% pcm13apr12
    { output.state after.block =
        {
	  add.closequote " " * write$	% pcm13apr12
          newline$
          "\newblock " write$
        }
        { output.state before.all =
            'write$
            { add.closequote " " * write$ }	% pcm13apr12
          if$
        }
      if$
      mid.sentence 'output.state :=
    }
  if$
  s
}

FUNCTION {closequote.output.nonnull}	% pcm13apr12
{ 's :=
  output.state mid.sentence =
    { ", " * write$ }
    { output.state after.block =
        {
	  add.comma add.closequote write$	% pcm13apr12
          newline$
          "\newblock " write$
        }
        { output.state before.all =
            'write$
            { add.comma write$ }	% pcm13apr12
          if$
        }
      if$
      mid.sentence 'output.state :=
    }
  if$
  s
}

FUNCTION {midsentence.closequote.output.nonnull} % pcm19jul2019 new function
{ 's :=
  output.state mid.sentence =
    { ",'' " * write$ } % pcm19jul2019 added close quotes after the comma
    { output.state after.block =
        {
	  add.comma add.closequote write$	% pcm13apr12
          newline$
          "\newblock " write$
        }
        { output.state before.all =
            'write$
            { add.comma write$ }	% pcm13apr12
          if$
        }
      if$
      mid.sentence 'output.state :=
    }
  if$
  s
}

FUNCTION {output}
{ duplicate$ empty$
    'pop$
    'output.nonnull
  if$
}

FUNCTION {nocomma.output}
{ duplicate$ empty$
    'pop$
    'nocomma.output.nonnull
  if$
}

FUNCTION {nocomma.closequote.output}
{ duplicate$ empty$
    'pop$
    'nocomma.closequote.output.nonnull
  if$
}

FUNCTION {closequote.output}	% pcm13apr12
{ duplicate$ empty$
    'pop$
    'closequote.output.nonnull
  if$
}

FUNCTION {midsentence.closequote.output} % pcm19jul2019 new function
{ duplicate$ empty$
    'pop$
    'midsentence.closequote.output.nonnull
  if$
}

FUNCTION {output.check}
{ 't :=
  duplicate$ empty$
    { pop$ "empty " t * " in " * cite$ * warning$ }
    'output.nonnull
  if$
}

FUNCTION {nocomma.output.check}
{ 't :=
  duplicate$ empty$
    { pop$ "empty " t * " in " * cite$ * warning$ }
    'nocomma.output.nonnull
  if$
}

FUNCTION {nocomma.closequote.output.check}
{ 't :=
  duplicate$ empty$
    { pop$ "empty " t * " in " * cite$ * warning$ }
    'nocomma.closequote.output.nonnull
  if$
}

FUNCTION {closequote.output.check}	% pcm13apr12
{ 't :=
  duplicate$ empty$
    { pop$ "empty " t * " in " * cite$ * warning$ }
    'closequote.output.nonnull
  if$
}

FUNCTION {midsentence.closequote.output.check} % pcm19jul2019 new function
{ 't :=
  duplicate$ empty$
    { pop$ "empty " t * " in " * cite$ * warning$ }
    'midsentence.closequote.output.nonnull
  if$
}

FUNCTION {fin.entry}
{ add.period$
  write$
  newline$
}

FUNCTION {noperiod.fin.entry} % pcm19jul2019
{ write$
  newline$
}

FUNCTION {new.block}
{ output.state before.all =
    'skip$
    { after.block 'output.state := }
  if$
}

FUNCTION {new.sentence}
{ output.state after.block =
    'skip$
    { output.state before.all =
        'skip$
        { after.sentence 'output.state := }
      if$
    }
  if$
}

FUNCTION {not}
{   { #0 }
    { #1 }
  if$
}

FUNCTION {and}
{   'skip$
    { pop$ #0 }
  if$
}

FUNCTION {or}
{   { pop$ #1 }
    'skip$
  if$
}

FUNCTION {new.block.checka}
{ empty$
    'skip$
    'new.block
  if$
}

FUNCTION {new.block.checkb}
{ empty$
  swap$ empty$
  and
    'skip$
    'new.block
  if$
}

FUNCTION {new.sentence.checka}
{ empty$
    'skip$
    'new.sentence
  if$
}

FUNCTION {new.sentence.checkb}
{ empty$
  swap$ empty$
  and
    'skip$
    'new.sentence
  if$
}

FUNCTION {field.or.null}
{ duplicate$ empty$
    { pop$ "" }
    'skip$
  if$
}

FUNCTION {emphasize}
{ duplicate$ empty$
    { pop$ "" }
    { "\emph{" swap$ * "}" * }
  if$
}

INTEGERS { nameptr namesleft numnames }

FUNCTION {format.names}
{ 's :=
  #1 'nameptr :=
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    % pcm25jul2019 spacing between author initials. TIS wanted no space back in 2013 - just figured it out
    %{ s nameptr "{f.~}{vv~}{ll}{, jj}" format.name$ 't := % full space between author initials - original
    %{ s nameptr "{f{.}.~}{vv~}{ll}{, jj}" format.name$ 't := % no space between author initials
    { s nameptr "{f{.\,}.~}{vv~}{ll}{, jj}" format.name$ 't := % thin space between author initials - looks best
      nameptr #1 >
        { namesleft #1 >
            { ", " * t * }
            { numnames #2 >
                { "," * }
                'skip$
              if$
              t "others" =
                { " et~al." * }
                { " and " * t * }
              if$
            }
          if$
        }
        't
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}

FUNCTION {format.key}
{ empty$
    { key field.or.null }
    { "" }
  if$
}

FUNCTION {format.authors}
{ author empty$
    { "" }
    { author format.names }
  if$
}

FUNCTION {format.editors}
{ editor empty$
    { "" }
    { editor format.names
      editor num.names$ #1 >
        { ", eds." * }
        { ", ed." * }
      if$
    }
  if$
}

FUNCTION {format.isbn}
{ isbn empty$
    { "" }
    { new.block "ISBN " isbn * }
  if$
}

FUNCTION {format.issn}
{ issn empty$
    { "" }
    { new.block "ISSN " issn * }
  if$
}

FUNCTION {format.url} % pcm25jul2019 added a preceding period
{ url empty$
    { "" }
    { new.block add.period$ "URL \url{" url * "}" * }
  if$
}

FUNCTION {nrl.format.note} % pcm25jul2019 new function with logic concerning a preceding url
{ note empty$
    { "" }
    { new.block
    url empty$
      { add.period$ "" note * }
      { "" note * }
    if$
    }
  if$
}

FUNCTION {nrl.output.note} % pcm25jul2019 new function with logic concerning a preceding url
{ url empty$
    { nocomma.output }
    { output }
  if$
}

FUNCTION {format.doi}
{ doi empty$
    { "" }
    { new.block "\doi{" doi * "}" * }
  if$
}

FUNCTION {format.title}
{ title empty$
    { "" }
    %{ title "t" change.case$ } % original: initial cap, downcase remainder of title
    { title } % pcm24oct leave title unchanged
  if$
}

FUNCTION {format.full.names}
{'s :=
  #1 'nameptr :=
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { s nameptr
      "{vv~}{ll}" format.name$ 't :=
      nameptr #1 >
        {
          namesleft #1 >
            { ", " * t * }
            {
              numnames #2 >
                { "," * }
                'skip$
              if$
              t "others" =
                { " et~al." * }
                { " and " * t * }
              if$
            }
          if$
        }
        't
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}

FUNCTION {author.editor.full}
{ author empty$
    { editor empty$
        { "" }
        { editor format.full.names }
      if$
    }
    { author format.full.names }
  if$
}

FUNCTION {author.full}
{ author empty$
    { "" }
    { author format.full.names }
  if$
}

FUNCTION {editor.full}
{ editor empty$
    { "" }
    { editor format.full.names }
  if$
}

FUNCTION {make.full.names}
{ type$ "book" =
  type$ "inbook" =
  or
    'author.editor.full
    { type$ "proceedings" =
        'editor.full
        'author.full
      if$
    }
  if$
}

FUNCTION {output.bibitem}
{ newline$
  "\bibitem[" write$
  label write$
  ")" make.full.names duplicate$ short.list =
     { pop$ }
     { * }
   if$
  "]{" * write$
  cite$ write$
  "}" write$
  newline$
  ""
  before.all 'output.state :=
}

FUNCTION {n.dashify}
{ 't :=
  ""
    { t empty$ not }
    { t #1 #1 substring$ "-" =
        { t #1 #2 substring$ "--" = not
            { "--" *
              t #2 global.max$ substring$ 't :=
            }
            {   { t #1 #1 substring$ "-" = }
                { "-" *
                  t #2 global.max$ substring$ 't :=
                }
              while$
            }
          if$
        }
        { t #1 #1 substring$ *
          t #2 global.max$ substring$ 't :=
        }
      if$
    }
  while$
}

FUNCTION {format.date}
{ year duplicate$ empty$
    { "empty year in " cite$ * warning$
       pop$ "" }
    'skip$
  if$
  month empty$
    'skip$
    { month
      " " * swap$ *
    }
  if$
  extra.label *
}

FUNCTION {format.btitle}
{ title emphasize
}

FUNCTION {tie.or.space.connect}
{ duplicate$ text.length$ #3 <
    { "~" }
    { " " }
  if$
  swap$ * *
}

FUNCTION {either.or.check}
{ empty$
    'pop$
    { "can't use both " swap$ * " fields in " * cite$ * warning$ }
  if$
}

FUNCTION {format.bvolume}
{ volume empty$
    { "" }
    { "volume" volume tie.or.space.connect
      series empty$
        'skip$
        { " of " * series emphasize * }
      if$
      "volume and number" number either.or.check
    }
  if$
}

FUNCTION {format.number.series}
{ volume empty$
    { number empty$
        { series field.or.null }
        { output.state mid.sentence =
            { "number" }
            { "Number" }
          if$
          number tie.or.space.connect
          series empty$
            { "there's a number but no series in " cite$ * warning$ }
            { " in " * series * }
          if$
        }
      if$
    }
    { "" }
  if$
}

FUNCTION {format.edition}
{ edition empty$
    { "" }
    { output.state mid.sentence =
        { edition "l" change.case$ " ed." * } % ktw20may19 changed from edition to ed.
        { edition "t" change.case$ " ed." * }  % ktw20may19 changed from edition to ed.
      if$
    }
  if$
}

INTEGERS { multiresult }

FUNCTION {multi.page.check}
{ 't :=
  #0 'multiresult :=
    { multiresult not
      t empty$ not
      and
    }
    { t #1 #1 substring$
      duplicate$ "-" =
      swap$ duplicate$ "," =
      swap$ "+" =
      or or
        { #1 'multiresult := }
        { t #2 global.max$ substring$ 't := }
      if$
    }
  while$
  multiresult
}

FUNCTION {format.pages}
{ pages empty$
    { "" }
    { pages multi.page.check
        { "pp." pages n.dashify tie.or.space.connect }
        { "p." pages tie.or.space.connect }
      if$
    }
  if$
}

FUNCTION {format.eid}
{ eid empty$
    { "" }
    { "art." eid tie.or.space.connect }
  if$
}

FUNCTION {format.vol.num.pages}
{ volume add.openbf add.closebf field.or.null	% pcm13apr12
  number empty$
    'skip$
    { "(" number * ")" * *
      volume empty$
        { "there's a number but no volume in " cite$ * warning$ }
        'skip$
      if$
    }
  if$
  pages empty$
    'skip$
    { duplicate$ empty$
        { pop$ format.pages }
        { ", " * pages n.dashify * }	% pcm13apr12
      if$
    }
  if$
}

FUNCTION {format.vol.num.eid}
{ volume add.openbf add.closebf field.or.null	% pcm13apr12
  number empty$
    'skip$
    { "(" number * ")" * *
      volume empty$
        { "there's a number but no volume in " cite$ * warning$ }
        'skip$
      if$
    }
  if$
  eid empty$
    'skip$
    { duplicate$ empty$
        { pop$ format.eid }
        { ", " * eid * }	% pcm13apr12
      if$
    }
  if$
}

FUNCTION {format.chapter.pages}
{ chapter empty$
    'format.pages
    { type empty$
        { "chapter" }
        { type "l" change.case$ }
      if$
      chapter tie.or.space.connect
      pages empty$
        'skip$
        { ", " * format.pages * }
      if$
    }
  if$
}

% pcm19jul2019 split format.in.ed.booktitle into two separate functions
% so that collection & proceedings formats may differ
FUNCTION {format.in.ed.booktitle.collection} % pcm19jul2019
{ booktitle empty$
    { "" }
    { editor empty$
        { "in " booktitle emphasize * } % original
        { "in " format.editors * ", " * booktitle emphasize * }
      if$
    }
  if$
}

FUNCTION {format.in.ed.booktitle.proceedings} % pcm19jul2019
{ booktitle empty$
    { "" }
    { editor empty$
        %{ "in " booktitle emphasize * } % original
        %{ "Presented at the " booktitle emphasize * } % KTW02JUN2019 TIS.1
        %{ "Proceedings of the " booktitle * emphasize } % pcm19jul2019 TIS.2
        { "Proceedings of the " booktitle * } % pcm19jul2019 TIS.3
        { "in " format.editors * ", " * booktitle emphasize * }
      if$
    }
  if$
}

FUNCTION {empty.misc.check}
{ author empty$ title empty$ howpublished empty$
  month empty$ year empty$ note empty$
  and and and and and
  key empty$ not and
    { "all relevant fields are empty in " cite$ * warning$ }
    'skip$
  if$
}

FUNCTION {format.thesis.type}
{ type empty$
    'skip$
    { pop$
      type "t" change.case$
    }
  if$
}

FUNCTION {format.tr.number}
{ type empty$
    %{ "rept." } % pcm13apr12
    { "" } % pcm19jul2019
    'type
  if$
  number empty$
    { "t" change.case$ }
    { number tie.or.space.connect }
  if$
}

FUNCTION {format.article.crossref}
{ key empty$
    { journal empty$
        { "need key or journal for " cite$ * " to crossref " * crossref *
          warning$
          ""
        }
        { "in \emph{" journal * "}" * }
      if$
    }
    { "in " }
  if$
  " \citet{" * crossref * "}" *
}

FUNCTION {format.journal}	% pcm13apr12
{ journal empty$
    { "need journal for " cite$ *
      warning$
      ""
    }
    { "\emph{" journal * "}" * }
  if$
}

FUNCTION {format.book.crossref}
{ volume empty$
    { "empty volume in " cite$ * "'s crossref of " * crossref * warning$
      "in "
    }
    { "Volume" volume tie.or.space.connect
      " of " *
    }
  if$
  editor empty$
  editor field.or.null author field.or.null =
  or
    { key empty$
        { series empty$
            { "need editor, key, or series for " cite$ * " to crossref " *
              crossref * warning$
              "" *
            }
            { "\emph{" * series * "}" * }
          if$
        }
        'skip$
      if$
    }
    'skip$
  if$
  " \citet{" * crossref * "}" *
}

FUNCTION {format.incoll.inproc.crossref}
{ editor empty$
  editor field.or.null author field.or.null =
  or
    { key empty$
        { booktitle empty$
            { "need editor, key, or booktitle for " cite$ * " to crossref " *
              crossref * warning$
              ""
            }
            { "in \emph{" booktitle * "}" * }
          if$
        }
        { "in " }
      if$
    }
    { "in " }
  if$
  " \citet{" * crossref * "}" *
}

FUNCTION {article}
{ output.bibitem
  format.authors "author" output.check
  author format.key output
  new.block
  format.title add.openquote "title" output.check	% pcm13apr12
  new.block
  crossref missing$
    { format.journal "journal" closequote.output.check		% pcm13apr12
      eid empty$
        { format.vol.num.pages nocomma.output }
        { format.vol.num.eid nocomma.output }
      if$
      format.date add.openparen add.closeparen "year" nocomma.output.check	% pcm13apr12
    }
    { format.article.crossref output.nonnull
      eid empty$
        { format.pages output }
        { format.eid output }
      if$
    }
  if$
  format.issn output
  format.doi output
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {book}
{ output.bibitem
  author empty$
    { format.editors "author and editor" output.check
      editor format.key output
    }
    { format.authors output.nonnull
      crossref missing$
        { "author and editor" editor either.or.check }
        'skip$
      if$
    }
  if$
  new.block
  format.btitle "title" output.check
  format.edition output % ktw05may19 Moved here from below
  crossref missing$
    { format.bvolume output
      new.block
      format.number.series output
      new.sentence
      publisher add.openparen "publisher" nocomma.output.check	% pcm13apr12
      address output
    }
    { new.block
      format.book.crossref output.nonnull
    }
  if$
  %format.edition output % ktw05may19 Moved above from here
  format.date add.closeparen "year" output.check	% pcm13apr12
  format.isbn output
  format.doi output
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {booklet}
{ output.bibitem
  format.authors output
  author format.key output
  new.block
  format.title add.openquote "title" output.check	% pcm13apr12
  howpublished address new.block.checkb
  howpublished output
  address closequote.output	% pcm13apr12
  format.date "year" nocomma.output.check	% pcm19jul2019 removed parenthesis
  format.isbn output
  format.doi output
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {inbook}
{ output.bibitem
  author empty$
    { format.editors "author and editor" output.check
      editor format.key output
    }
    { format.authors output.nonnull
      crossref missing$
        { "author and editor" editor either.or.check }
        'skip$
      if$
    }
  if$
  new.block
  format.btitle "title" output.check
  crossref missing$
    { format.bvolume output
      format.chapter.pages "chapter and pages" output.check
      new.block
      format.number.series output
      new.sentence
      publisher add.openparen "publisher" nocomma.output.check	% pcm13apr12
      address output
    }
    { format.chapter.pages "chapter and pages" output.check
      new.block
      format.book.crossref output.nonnull
    }
  if$
  format.edition output
  format.date add.closeparen "year" output.check	% pcm13apr12
  format.isbn output
  format.doi output
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {incollection}
{ output.bibitem
  format.authors "author" output.check
  author format.key output
  new.block
  format.title add.openquote "title" output.check	% pcm13apr12
  new.block
  crossref missing$
    { format.in.ed.booktitle.collection "booktitle" closequote.output.check% pcm19jul2019 new function name
      format.bvolume output
      format.number.series output
      format.chapter.pages output
      new.sentence
      publisher add.openparen "publisher" nocomma.output.check
      address output
      format.edition output
      publisher missing$% pcm25jul2019
	{ format.date "year" output.check }
	{ format.date add.closeparen "year" output.check }
      if$
    }
    { format.incoll.inproc.crossref output.nonnull
      format.chapter.pages output
    }
  if$
  format.isbn output
  format.doi output
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {nrl.inproc.organization.publisher} % pcm22aug2019 new function
{ % make an "(organization, publisher)" string
  % operator * concatenates the pair of strings residing in the top two stack positions
  organization missing$ publisher missing$ and
    'skip$ % and return
    { "(" % push an open paren string onto the stack
      organization missing$
	'skip$
	{ organization * } % append it to the output string
      if$
      organization missing$ not publisher missing$ not and
	{ ", " * } % both are present, add a comma between them
	'skip$
      if$
      publisher missing$
	'skip$
	{ publisher * } % append it to the output string
      if$
      ")" * % append a closing paren to the output string
      nocomma.output % write string without a comma between "address" and "(organization, publisher)"
    }
  if$
}

FUNCTION {nrl.inproc.isbn} % pcm22aug2019
{ isbn missing$
  'skip$
  { add.period format.isbn nocomma.output }
  if$
}

FUNCTION {nrl.inproc.doi} % pcm22aug2019
{ doi missing$
    'skip$
    { isbn missing$
	{ add.period }
	{ add.comma }
      if$
      format.doi nocomma.output
    }
  if$
}

FUNCTION {nrl.inproc.url} % pcm22aug2019
{ url missing$
  'skip$
  { format.url nocomma.output }
  if$
}

FUNCTION {nrl.inproc.note} % pcm22aug2019
{ note missing$
  'skip$
  { nrl.format.note nrl.output.note }
  if$
}

FUNCTION {inproceedings} % pcm22aug2019 total rewrite
{ output.bibitem
  format.authors "author" output.check
  author format.key output
  new.block
  format.title add.openquote "title" output.check
  new.block
  crossref missing$
    {
      format.in.ed.booktitle.proceedings "booktitle" closequote.output.check
      format.bvolume output
      format.number.series output
      howpublished missing$
	'skip$
	{ format.date  "year" output.check } %  conference dates
      if$
      address output
      nrl.inproc.organization.publisher
      howpublished missing$
	{ format.date "year" output.check } % use conference dates when howpublished is missing
	{ howpublished output } % use howpublished for the date proceedings were actually published
      if$
      format.pages output
    }
    { format.incoll.inproc.crossref output.nonnull }
  if$
  nrl.inproc.isbn
  nrl.inproc.doi
  nrl.inproc.url
  nrl.inproc.note
  fin.entry
}

FUNCTION {conference} { inproceedings }

FUNCTION {manual}
{ output.bibitem
  format.authors output
  author format.key output
  new.block
  format.btitle "title" output.check
  organization address new.block.checkb
  organization add.openparen "organization" nocomma.output.check	% pcm13apr12
  address output
  format.edition output
  format.date add.closeparen output
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {mastersthesis}
{ output.bibitem
  format.authors "author" output.check
  author format.key output
  new.block
  format.title add.openquote "title" output.check	% pcm13apr12
  new.block
  "Master's thesis" format.thesis.type closequote.output.nonnull	% pcm13apr12
  school add.openparen "school" nocomma.output.check	% pcm13apr12
  address output
  format.date add.closeparen "year" output.check	% pcm13apr12
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {nrl.misc.howpublished} % pcm19jul2019
{
  howpublished new.block.checka
  howpublished missing$
    { new.block }
    { howpublished closequote.output }
  if$
}

FUNCTION {nrl.misc.year} % pcm19jul2019
{ year new.block.checka
  howpublished missing$
    { year missing$
	'skip$
	{ format.date "year" closequote.output.check }
      if$
    }
    { year missing$% with howpublished present
	'skip$
	{ format.date "year" output.check }
      if$
    }
  if$
}

FUNCTION {nrl.misc.issn} % pcm19jul2019
{ issn new.block.checka
  howpublished missing$ year missing$ and
    { format.issn closequote.output }
    { format.issn output }
  if$
}

FUNCTION {nrl.misc.url} % pcm19jul2019
{ url new.block.checka
  howpublished missing$ year missing$ issn missing$ and and
    { format.url nocomma.closequote.output }
    { format.url nocomma.output } % pm25jul2019 removed a comma
  if$
}

FUNCTION {nrl.misc.note} % pcm19jul2019
{ note new.block.checka
  howpublished missing$ year missing$ issn missing$ url missing$ and and and
    { note closequote.output }
    { nrl.format.note nrl.output.note }
  if$
}

FUNCTION {nrl.misc.fin.entry} % pcm19jul2019
{ howpublished missing$ year missing$ issn missing$ url missing$ note missing$ and and and and
    { ".''" swap$ write$
      noperiod.fin.entry
    }
    { fin.entry }
  if$
}

% The idea here is to make misc robust to missing fields.
% The ordering of the fields in this function cannot be changed without
% also editing the missing$ logicals in the above functions to match the order.
FUNCTION {misc} % pcm19jul2019
{ output.bibitem
  format.authors output
  author format.key output
  title howpublished new.block.checkb
  format.title add.openquote "title" add.closequote output.check
  nrl.misc.howpublished
  nrl.misc.year
  nrl.misc.issn
  nrl.misc.url
  nrl.misc.note
  nrl.misc.fin.entry
  empty.misc.check
}

% A new BibTeX entry for footnotes
% and whatever NOTE you wish to include.
FUNCTION {notes}	% pcm13apr12
{ output.bibitem
  new.block
  note "note" nocomma.output.check
  fin.entry
  empty.misc.check
}

FUNCTION {phdthesis}
{ output.bibitem
  format.authors "author" output.check
  author format.key output
  new.block
  format.btitle "title" output.check
  new.block
  "PhD thesis" format.thesis.type output.nonnull
  school add.openparen "school" nocomma.output.check	% pcm13apr12
  address output
  format.date add.closeparen "year" output.check	% pcm13apr12
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {proceedings}
{ output.bibitem
  format.editors output
  editor format.key output
  new.block
  format.btitle "title" output.check
  format.bvolume output
  format.number.series output
  address output
  format.date "year" output.check
  new.sentence
  organization missing$ publisher missing$ or	% pcm13apr12
    { organization missing$
	{ publisher add.openparen add.closeparen nocomma.output
	}
	{ organization add.openparen add.closeparen nocomma.output
	}
      if$
    }
    { organization add.openparen nocomma.output
      publisher add.closeparen output
    }
  if$
  format.isbn output
  format.doi output
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {techreport}
{ output.bibitem
  format.authors "author" output.check
  author format.key output
  new.block
  format.title add.openquote "title" output.check	% pcm13apr12
  new.block
  number missing$% pcm19jul2019
  { institution "institution" closequote.output.check
  }
  { format.tr.number closequote.output.nonnull
    institution "institution" output.check
  }
  if$
  address output
  format.date "year" output.check	% ktw 20may19
  format.url nocomma.output% pm25jul2019 removed a comma
  new.block
  nrl.format.note nrl.output.note
  fin.entry
}

FUNCTION {unpublished}
{ output.bibitem
  format.authors "author" output.check
  author format.key output
  new.block
  format.title add.openquote "title" output.check	% pcm13apr12
  new.block
  note "note" closequote.output.check	% pcm13apr12
  format.date add.openparen add.closeparen "year" nocomma.output.check	% pcm13apr12
  format.url nocomma.output% pm25jul2019 removed a comma
  fin.entry
}

FUNCTION {default.type} { misc }


MACRO {jan} {"Jan."}

MACRO {feb} {"Feb."}

MACRO {mar} {"Mar."}

MACRO {apr} {"Apr."}

MACRO {may} {"May"}

MACRO {jun} {"June"}

MACRO {jul} {"July"}

MACRO {aug} {"Aug."}

MACRO {sep} {"Sept."}

MACRO {oct} {"Oct."}

MACRO {nov} {"Nov."}

MACRO {dec} {"Dec."}



MACRO {acmcs} {"ACM Comput. Surv."}

MACRO {acta} {"Acta Inf."}

MACRO {cacm} {"Commun. ACM"}

MACRO {ibmjrd} {"IBM J. Res. Dev."}

MACRO {ibmsj} {"IBM Syst.~J."}

MACRO {ieeese} {"IEEE Trans. Softw. Eng."}

MACRO {ieeetc} {"IEEE Trans. Comput."}

MACRO {ieeetcad}
 {"IEEE Trans. Comput.-Aided Design Integrated Circuits"}

MACRO {ipl} {"Inf. Process. Lett."}

MACRO {jacm} {"J.~ACM"}

MACRO {jcss} {"J.~Comput. Syst. Sci."}

MACRO {scp} {"Sci. Comput. Programming"}

MACRO {sicomp} {"SIAM J. Comput."}

MACRO {tocs} {"ACM Trans. Comput. Syst."}

MACRO {tods} {"ACM Trans. Database Syst."}

MACRO {tog} {"ACM Trans. Gr."}

MACRO {toms} {"ACM Trans. Math. Softw."}

MACRO {toois} {"ACM Trans. Office Inf. Syst."}

MACRO {toplas} {"ACM Trans. Prog. Lang. Syst."}

MACRO {tcs} {"Theoretical Comput. Sci."}

MACRO {jasa} {"J.~Acoust. Soc. Am."}	% pcm13apr12

MACRO {joe} {"IEEE J.~Ocean. Eng."}	% pcm13apr12

MACRO {jgr} {"J.~Geophys. Res."}	% pcm13apr12

MACRO {jcp} {"J.~Comp. Phys."}		% pcm13apr12


READ

FUNCTION {sortify}
{ purify$
  "l" change.case$
}

INTEGERS { len }

FUNCTION {chop.word}
{ 's :=
  'len :=
  s #1 len substring$ =
    { s len #1 + global.max$ substring$ }
    's
  if$
}

FUNCTION {format.lab.names}
{ 's :=
  s #1 "{vv~}{ll}" format.name$
  s num.names$ duplicate$
  #2 >
    { pop$ " et~al." * }
    { #2 <
        'skip$
        { s #2 "{ff }{vv }{ll}{ jj}" format.name$ "others" =
            { " et~al." * }
            { " and " * s #2 "{vv~}{ll}" format.name$ * }
          if$
        }
      if$
    }
  if$
}

FUNCTION {author.key.label}
{ author empty$
    { key empty$
        { cite$ #1 #3 substring$ }
        'key
      if$
    }
    { author format.lab.names }
  if$
}

FUNCTION {author.editor.key.label}
{ author empty$
    { editor empty$
        { key empty$
            { cite$ #1 #3 substring$ }
            'key
          if$
        }
        { editor format.lab.names }
      if$
    }
    { author format.lab.names }
  if$
}

FUNCTION {author.key.organization.label}
{ author empty$
    { key empty$
        { organization empty$
            { cite$ #1 #3 substring$ }
            { "The " #4 organization chop.word #3 text.prefix$ }
          if$
        }
        'key
      if$
    }
    { author format.lab.names }
  if$
}

FUNCTION {editor.key.organization.label}
{ editor empty$
    { key empty$
        { organization empty$
            { cite$ #1 #3 substring$ }
            { "The " #4 organization chop.word #3 text.prefix$ }
          if$
        }
        'key
      if$
    }
    { editor format.lab.names }
  if$
}

FUNCTION {calc.short.authors}
{ type$ "book" =
  type$ "inbook" =
  or
    'author.editor.key.label
    { type$ "proceedings" =
        'editor.key.organization.label
        { type$ "manual" =
            'author.key.organization.label
            'author.key.label
          if$
        }
      if$
    }
  if$
  'short.list :=
}

FUNCTION {calc.label}
{ calc.short.authors
  short.list
  "("
  *
  year duplicate$ empty$
  short.list key field.or.null = or
     { pop$ "" }
     'skip$
  if$
  *
  'label :=
}

INTEGERS { seq.num }

FUNCTION {init.seq}
{ #0 'seq.num :=}

EXECUTE {init.seq}

FUNCTION {int.to.fix}
{ "000000000" swap$ int.to.str$ *
  #-1 #10 substring$
}


FUNCTION {presort}
{ calc.label
  label sortify
  "    "
  *
  seq.num #1 + 'seq.num :=
  seq.num  int.to.fix
  'sort.label :=
  sort.label *
  #1 entry.max$ substring$
  'sort.key$ :=
}

ITERATE {presort}

SORT

STRINGS { longest.label last.label next.extra }

INTEGERS { longest.label.width last.extra.num number.label }

FUNCTION {initialize.longest.label}
{ "" 'longest.label :=
  #0 int.to.chr$ 'last.label :=
  "" 'next.extra :=
  #0 'longest.label.width :=
  #0 'last.extra.num :=
  #0 'number.label :=
}

FUNCTION {forward.pass}
{ last.label label =
    { last.extra.num #1 + 'last.extra.num :=
      last.extra.num int.to.chr$ 'extra.label :=
    }
    { "a" chr.to.int$ 'last.extra.num :=
      "" 'extra.label :=
      label 'last.label :=
    }
  if$
  number.label #1 + 'number.label :=
}

FUNCTION {reverse.pass}
{ next.extra "b" =
    { "a" 'extra.label := }
    'skip$
  if$
  extra.label 'next.extra :=
  extra.label
  duplicate$ empty$
    'skip$
    { "{\natexlab{" swap$ * "}}" * }
  if$
  'extra.label :=
  label extra.label * 'label :=
}

EXECUTE {initialize.longest.label}

ITERATE {forward.pass}

REVERSE {reverse.pass}

FUNCTION {bib.sort.order}
{ sort.label  'sort.key$ :=
}

ITERATE {bib.sort.order}

SORT

FUNCTION {begin.bib}
{   preamble$ empty$
    'skip$
    { preamble$ write$ newline$ }
  if$
  "\begin{thebibliography}{" number.label int.to.str$ * "}" *
  write$ newline$
  "\providecommand{\natexlab}[1]{#1}"
  write$ newline$
  "\providecommand{\url}[1]{\texttt{#1}}"
  write$ newline$
  "\expandafter\ifx\csname urlstyle\endcsname\relax"
  write$ newline$
  "  \providecommand{\doi}[1]{doi: #1}\else"
  write$ newline$
  "  \providecommand{\doi}{doi: \begingroup \urlstyle{rm}\Url}\fi"
  write$ newline$
}

EXECUTE {begin.bib}

EXECUTE {init.state.consts}

ITERATE {call.type$}

FUNCTION {end.bib}
{ newline$
  "\end{thebibliography}" write$ newline$
}

EXECUTE {end.bib}
