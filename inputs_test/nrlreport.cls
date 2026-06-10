%%
%% This is file 'nrlreport.cls'
%%
%% Created by Dr. Michael Kluskens (MSKNRL), Naval Research Laboratory, Code 5314
%% Based on changes from report.cls, with pieces from amsdtx.cls, genthesis.cls, and
%% nrl.sty (by David Fromm, Naval Research Laboratory, Code 7142)
%%
%% Changes by Peter Mignerey (pcm) Code 7167, April 2012 -- Feb 2022
%% include: hyperref, BibTeX, subparagraphs, figures, tables, appendices,
%%   executive summary, title, and report documentation pages.
%%
%% Currently maintained by Dan Scholnik (dps), Code 5341
%% Email: dan.scholnik@nrl.navy.mil
%%   
%% Report bugs to dan.scholnik@nrl.navy.mil
%% If possible reference recent NRL Formal Reports showing correct format
%%
%% Changes by Peter Mignerey:
%% Citation and bibliography formats were added that work with BibTeX.
%% Bibunits were added so that each appendix numbers its citations separately.
%%   See bibliography and citation choices at the end of this file.
%% The code for chapter headings was modified to correctly list the page number in the contents.
%% A "REFERENCES" item was added to the table of contents.
%% Also added were some macros for common cross references,
%%   e.g. \eqn & \fig - use them for uniformity and to simplify changes.
%%   TIS wants "Section", "Table", and "Appendix" fully spelled out everwhere.
%% The NRL report title page was redone to more closely mimic the report style with a logo.
%% Commands for nrlreportnumber and nrldistribution were added -
%%   declare them in your paper once you know them.
%% All package requirements were moved up front except for hyperref which needs to be last.
%% The Executive Summary was redone so that numbers appear on all pages.
%% Appendix page numbering now continues in sequence with the main-document page numbering.
%% Figures and Tables are now automatically centered with correct font size in the captions.
%% Tables now use threeparttable to make table notes.
%% Indentation of subsection, paragraph, and subparagraph headings were fixed.
%% Tolerance on bottom margins was relaxed a little to avoid club lines (widows & orphans).
%% A "branch" command has been added to augment the "author" command for the title page.
%% More branches were added: authortwo, branchtwo, authorthree, and branchthree.
%% An "NRLabstract" command was created to make an SF-298 form with an embedded abstract.
%%
%% Changes by Dan Scholnik:
%% Added \deceased{date} command for author lists, with annotation on title page and SF-298
%% Added \nrloutsideaddress{addr}, \nrloutsideaddresstwo{addr}, etc. for non-NRL authors, and added the
%% outside addresses to the SF-298 w/ annotations indicating the corresponding author groups
%% Added unicode font compatibility, for use with lualatex and xelatex (not compatible with pdflatex)
%% This includes the unicode-math package, which offers straightforward access to all styles in a font
%% Unicode is enabled via the "unicode" option, with several math font options:
%% Termes, STIX, XITS, Cambria
%% Added "oneside" option to eliminate blank left-side pages, especially in the appendices.  (Not for formal reports)
%% 
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{nrlreport}[2023/02/21]% version

% add single and double space options %pcm4dec14
\newif\ifnrl@dblspc
\newif\if@openany

\DeclareOption{doublespace}{\nrl@dblspctrue}
\DeclareOption{singlespace}{\nrl@dblspcfalse}
\DeclareOption{openany}{\@openanytrue}

% add oneside option for memo/other reports, and matching twoside option for completeness
\DeclareOption{oneside}{\@twosidefalse} % @twoside conditional defined in latex.ltx
\DeclareOption{twoside}{\@twosidetrue}

% font size options %pcm20jun2016
\DeclareOption{10pt}{\def\nrl@loadfont{\nrl@loadfont@sizeXpt}}
\DeclareOption{11pt}{\def\nrl@loadfont{\nrl@loadfont@sizeXIpt}}
\DeclareOption{12pt}{\def\nrl@loadfont{\nrl@loadfont@sizeXIIpt}}

% unicode font family options
\newif\if@unicode 
\@unicodefalse % default is NFSS (pdflatex)
\DeclareOption{unicode}{\@unicodetrue}
\newif\if@Termes
\newif\if@XITS
\newif\if@STIX
\newif\if@Cambria
\@Termestrue % default
\DeclareOption{Termes}{\@unicodetrue \@Termestrue \@XITSfalse \@STIXfalse \@Cambriafalse}
\DeclareOption{XITS}{\@unicodetrue \@XITStrue \@Termesfalse \@STIXfalse \@Cambriafalse}
\DeclareOption{STIX}{\@unicodetrue \@STIXtrue \@Termesfalse \@XITSfalse \@Cambriafalse}
\DeclareOption{Cambria}{\@unicodetrue \@Cambriatrue \@Termesfalse \@XITSfalse \@STIXfalse}

% pass unknown options (openright) to report.cls
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{report}}

\ExecuteOptions{11pt,singlespace,twoside,xcolor={hyperref,table,fixpdftex,xcdraw}}% set default options, TIS wants 11pt font size
\ProcessOptions% set user options

\if@twoside % I don't think report will inherit the oneside/twoside options, so call explicitly
\LoadClass[twoside]{report}% fontsize is loaded by nrl@loadfont
\else
\LoadClass[oneside]{report}% fontsize is loaded by nrl@loadfont
\fi

\typeout{nrlreport.cls 2023-02-21}% version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% check if unicode is enabled with an unsupported engine (latex, pdflatex) and throw an error if so
\RequirePackage{iftex} % contains checks for tex engine
\if@unicode
   \iftutex
   % do nothing
   \else
   % Throw an error
   \ClassError{nrlreport}{This tex engine does not support Unicode}{The ``unicode'' option or any of the unicode font options requires a unicode-capable TeX engine like luatex or xetex}
   \fi
\fi

% Moved this up front to set options prior to newtxtext, which calls it with no options.  CLashes in 2023.  %dps29nov2023
\RequirePackage[hyperref,table,fixpdftex,xcdraw]{xcolor}% needed for colored title page & table cellcolor %pcm14jun2021

% Check if we are using unicode or not, and setup fonts/packages accordingly
\if@unicode % using unicode fonts
\RequirePackage{mathtools} % want before unicode-math

% The below is the new way to setup math for "modern" latex variants (xelatex and lualatex)
% New symbol font commands \sumup, \symit, \symbf, \symbfup, and \symbfit are mostly consistent across latin and greek characters
% The ISO/TeX option sets some upright/italic defaults for regular and \symbf symbols
% The old \mathbf, etc. options still apply to _text_ characters used in math (i.e. for labels)
%\RequirePackage[math-style=ISO,bold-style=ISO]{unicode-math} % ISO recommendations (medium and bold default to italic)
\RequirePackage[math-style=TeX,bold-style=TeX]{unicode-math} % standard LaTeX math conventions (bold latin and capital Greek default to upright)
\defaultfontfeatures{ Scale=MatchLowercase, Ligatures=TeX }

% Times-like font used by newtx, has small integrals and too-fancy mathcal, so will do selective replacements
\if@Termes
%\setmainfont{TeX Gyre Termes}[Scale=1.0] % This is about the same size as Times
\setmainfont{TeX Gyre TermesX}[Scale=1.0] % Supposed to match newtxtext? (No matching math version)
\setmathfont{TeX Gyre Termes Math}
%% replace integrals with larger ones (Termes ones are a bit short)
% integrals from STIX2 (larger): my favorite so far
 \setmathfont[range={"222B-"2233,"2A0B-"2A1C}]{STIX Two Math}[Scale=1.01]
% \setmathfont[range={"222B-"2233,"2A0B-"2A1C}]{XITS Math} % replace integrals with those from XITS
% XITS upright integrals, don't really like
% \setmathfont{XITS Math}[range={"222B-"2233, "2A0C-"2A1C},Scale=MatchUppercase,StylisticSet=8]
% Latin modern is too thin
% \setmathfont{Latin Modern Math}[range={"222B-"2233, "2A0C-"2A1C},Scale=MatchUppercase]
%
% Replace cal and bfcal
%\setmathfont{DejaVu Math TeX Gyre}[range={cal,bfcal},Scale=MatchUppercase] % decent shape, maybe a touch light
\setmathfont[range={cal,bfcal}]{STIX Two Math}[Scale=1.01] % good "U", but funny "T"
%\setmathfont[range={cal,bfcal}]{XITS Math}[StylisticSet=1] % good "T", but funny "U"
%\setmathfont{Latin Modern Math}[range={cal,bfcal},Scale=MatchUppercase] % decent shape, but too light
\fi % \if@Termes

% Times-like.  Fork of STIX
\if@XITS
%\setmainfont{XITS}[Scale=0.985] % to match Termes
\setmainfont{XITS}[Scale=1.0] % to match Times
\setmathfont{XITS Math} % scale matches text by default
\fi % \if@XITS

% Times-like, but math font is a bit different from XITS and the text font is a bit different in
% shape and scaling than Times so we will not use that here.
\if@STIX
%\setmainfont{Times New Roman}[Scale=1.0]
\setmainfont{TeX Gyre TermesX}[Scale=1.0] % Supposed to match newtxtext?
%\setmainfont{TeX Gyre Termes}[Scale=1.0] % close match to Times
\setmathfont{STIX Two Math}[Scale=1.01] % STIX2 needs manual scaling, this seems to best match Times
\fi % \if@STIX

% Cambria: Microsoft Times-like font
\if@Cambria
%\setmainfont{Cambria}[Scale=0.925] % match Termes scaling
\setmainfont{Cambria}[Scale=0.95] % match Times scaling
\setmathfont{Cambria Math} % scale matches text by default
\fi % \if@Cambria

%\setsansfont{Arial}[Scale=0.9] % need a smaller, Helvetica-like font for the Report Documentation Page, not used otherwise?
%\setsansfont{Nimbus Sans}[Scale=0.9] % avoids any Arial license issues
\setsansfont{TeX Gyre Heros}[Scale=0.9] % another option

\else % using classic NFSS
% Dan Scholnik suggests we use New TX fonts, and we are doing so. %pcm14feb2021
% Thanks Dan!
\RequirePackage{newtxtext} % Dan Scholnik-2020-05-01
\RequirePackage{newtxmath} % Dan Scholnik-2020-05-01
\let\bm\boldsymbol			% bold Greek math symbols
%obsolete: times, mathptmx, amsmath, amssymb, colonequals, bm
\fi

% provide backward compatibility %pcm15feb2021
\let\colonequals\coloneq % use let, newcommand doesn't always work %pcm14feb2021

% Common packages
\RequirePackage[current]{latexrelease} % "current" is default, uses the native version.  Package provides \IncludeInRelease for condition compilation

% Need "nopatch=toc" for latex 2022-06 and after, but the option was introduced sometime after v2.8c (2021/03/14) and before v3.1 (2023/03/06)
% Hopefully it was added before or concurrent with the 2022 latex release
\IncludeInRelease{2022/06/01}{\mttocfix}{Microtype toc fix}
   \RequirePackage[nopatch=toc]{microtype} % is supported in pdftex, luatex, and xetex, but pdftex>luatex>xetex in terms of features
\EndIncludeInRelease
\IncludeInRelease{0000/00/00}{\mttocfix}{Microtype toc fix}
   \RequirePackage{microtype} % is supported in pdftex, luatex, and xetex, but pdftex>luatex>xetex in terms of features
\EndIncludeInRelease

\RequirePackage{graphicx}		% needed by includegraphics for logo & author's figures
%\RequirePackage[hyperref,table,fixpdftex,xcdraw]{xcolor}% needed for colored title page & table cellcolor %pcm14jun2021
\RequirePackage{afterpage}              % needed for colored title page

\RequirePackage[numbers,sort&compress]{natbib} % bibliography formats are based on natbib %pcm15sep2021 added numbers
\RequirePackage{bibunits} % must follow natbib - needed to make separate bibliographies for appendices
\RequirePackage[overload]{textcase}	% smarter uppercase and lowercase conversions

\let\counterwithout\relax		% fix chngcntr.sty bug - pcm14feb2019
\let\counterwithin\relax		% fix double definition of counterwithout/within
\RequirePackage{chngcntr}		% enables control over footnote counter resets

\RequirePackage{calc}			% enables length computations
\RequirePackage{varwidth}% provides a natural-width minipage environment needed by nrlfigure, nrltable & caveats
\RequirePackage{threeparttable}		% enables table notes
\RequirePackage{longtable}		% need to modify format of longtable captions %pcm01jul2021
\RequirePackage{listings}		% provide source-code listings & modify their captions%pcm07oct2021

\RequirePackage{xstring}  % allows replacing substrings, used here to remove newlines from addresses

\RequirePackage{environ}  % provides command for defining environments with \BODY available as a macro

% Note: currently this class defines a custom caption formatting command, and redefines the figure and
% table enviroments to use it.  It also defines nrlfigure and nrlfigurew environments which also use the
% custom caption.  So the caption package won't affect those without further changes.  But caption is included
% by other common packages, and in some cases (like rotating.sty) caption redefines commands in a way that
% overrides the caption formatting.  Long term I should just use caption.sty for all captions, but in the short
% term the safe thing to do is to include it here and set the formatting to match the custom command, to catch
% cases that might otherwise be missed.
\RequirePackage{caption} % clean way to adjust caption formatting.  
\DeclareCaptionLabelSeparator*{emdash}{---} % star variant doesn't apply labelfont setting
\captionsetup[figure]{width=0.7\textwidth,font=footnotesize,labelfont=normalfont,labelsep=emdash}

%\RequirePackage{hyperref} 	% hot links to sections, refs, eqns, figs, tables, etc.
%				  breaks if not included at the end of this file
% see below for: hyperref, doi & zref-totpages

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%pcm4dec14 set the interline spacing
\ifnrl@dblspc
  \renewcommand{\baselinestretch}{2.0}% double space
\else
  \renewcommand{\baselinestretch}{1.0}% single space
\fi

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%\renewcommand\bibnumfmt[1]{#1.}
% (line 139)
\setcounter{topnumber}{3}
\renewcommand\topfraction{.8}%DF=0.8,ams=0.97,report=0.7
\setcounter{bottomnumber}{3}
\renewcommand\bottomfraction{.5}%DF=0.5,ams=0.97,report=0.3
\setcounter{totalnumber}{3}
\renewcommand\textfraction{.2}%DF=0.2,ams=0.03,report=0.2
\renewcommand\floatpagefraction{.65}%DF=0.5,ams=0.9,report=0.5
\setcounter{dbltopnumber}{2}
%\renewcommand\dbltopfraction{.9}%DF=0.7,ams=0.97,report=0.7
%\renewcommand\dblfloatpagefraction{.9}%DF=0.5,ams=0.9,report=0.5

% Specify the typeface and size of the page markings.
% \fontsize{size}{skip}
\def\nrl@markfont{\sffamily\bfseries\fontsize{14pt}{16pt}\selectfont}%dps07may2022
\def\nrl@markfontBig{\sffamily\bfseries\fontsize{20pt}{22pt}\selectfont}%dps07may2022

% save the mark for future use.
\newcommand\nrlmark[1]{\def\nrl@savedmark{#1}}%pcm14may2018

% default security mark is empty
\nrlmark{}%pcm20jun2016

% (U) needed for security by CONTENTS, FIGURES, TABLES, REFERENCES, ACKNOWLEDGEMENTS, EXECUTIVE SUMMARY
% CUI papers are marked but not classified %pcm14feb2021
% TeX cannot easily compare strings unless they are encapsulated within defs.
\def\nrl@CUImark{CUI}% needs to be out here
\def\nrl@markU{%
  \ifx\nrl@savedmark\@empty\relax%
  \else\ifx\nrl@savedmark\nrl@CUImark\relax%
  \else{(U)~}%
  \fi\fi%
}%

% nrl@markinsert & Big are used internally to typset marking text in the head & foot of each page
\def\nrl@markinsert{\nrl@markfont\nrl@savedmark}%pcm20jun2016
\def\nrl@markinsertBig{\nrl@markfontBig\nrl@savedmark}%pcm20jun2016

% define headers & footers for normal pages
\def\ps@headings{%pcm01dec2016
  \def\@evenhead{
    \parbox[b][\headheight][b]{\textwidth} {
      \ifx\nrl@savedmark\@empty\relax
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}\\%
      \fi
      \makebox[\textwidth][c]{\thepage\hfill{\itshape\nrl@headerauthor}\strut}%pcm07oct2021
      \vfill\hrule
  }}%
  \def\@oddhead{
    \parbox[b][\headheight][b]{\textwidth}{
      \ifx\nrl@savedmark\@empty\relax
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}\\%
      \fi
      \makebox[\textwidth][c]{{\itshape\nrl@headertitle}\hfill\thepage\strut}%pcm07oct2021
      \vfill\hrule
  }}%
  \def\@evenfoot{
    \parbox[b][\footheight][b]{\textwidth}{
      \ifx\nrl@savedmark\@empty\relax
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}%
      \fi
  }}%
  \def\@oddfoot{
    \parbox[b][\footheight][b]{\textwidth}{
      \ifx\nrl@savedmark\@empty\relax
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}%
      \fi
  }}%
  \let\@mkboth\markboth
  \def\chaptermark##1{%
    \markboth {\MakeTextUppercase{%
        \ifnum \c@secnumdepth >\m@ne
        \@chapapp\ \thechapter. \ %
        \fi
        ##1}}{}}%
  \def\sectionmark##1{%
    \markright {%
      \ifnum \c@secnumdepth >\z@
      \thesection. \ %
      \fi
      ##1}}}

% define special headers & footers for preamble pages, the first chapter and each appendix
\def\ps@plain{%pcm01dec2016
  \def\@evenhead{
    \parbox[b][\headheight][b]{\textwidth}{
      \ifx\nrl@savedmark\@empty\relax
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}%
      \fi
  }}%
  \def\@oddhead{
    \parbox[b][\headheight][b]{\textwidth}{
      \ifx\nrl@savedmark\@empty\relax
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}%
      \fi
  }}%
  \def\@evenfoot{
    \parbox[b][\footheight][b]{\textwidth}{
      \makebox[\textwidth][c]{\hfill\thepage\hfill}%
      \ifx\nrl@savedmark\@empty\relax
      \else\\\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}%
      \fi
  }}%
  \def\@oddfoot{
    \parbox[b][\footheight][b]{\textwidth}{
      \makebox[\textwidth][c]{\hfill\thepage\hfill}%
      \ifx\nrl@savedmark\@empty\relax
      \else\\\makebox[\textwidth][c]{\hfill\nrl@markinsert\hfill}%
      \fi
  }}%
  \let\@mkboth\markboth
  \def\chaptermark##1{%
    \markboth {\MakeTextUppercase{%
        \ifnum \c@secnumdepth >\m@ne
        \@chapapp\ \thechapter. \ %
        \fi
        ##1}}{}}%
  \def\sectionmark##1{%
    \markright {%
      \ifnum \c@secnumdepth >\z@
      \thesection. \ %
      \fi
      ##1}}}

% set default page style throughout the preamble of the paper until first chapter is begun
\pagestyle{plain}%pcm29jul2016

% define special headers & footers for the title page %pcm01dec2016
% title page is odd, all empty pages are even
\def\ps@myheadings{
  \def\@oddhead{}% title page
  %% This function was moved to the title page because background images & colors cover the top mark.
  %  \parbox[b][\headheight][b]{\textwidth}{%
  %    \ifx\nrl@savedmark\@empty\relax%
  %    \else\makebox[\textwidth][c]{\hfill\nrl@markinsertBig\hfill}\vspace{2.8em}% raise the mark
  %    \fi
  %}}%
  \def\@oddfoot{% title page
    \parbox[t][\footheight][b]{\textwidth}{%
      \ifx\nrl@savedmark\@empty%
        \makebox[\textwidth][c]{\hfill\nrl@distributionmark\hfill}%msk16sep2020
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsertBig\hfill}%
      \fi
  }}%
  \def\@evenhead{% empty page
    \ifx\nrl@savedmark\@empty\relax%
    \else\makebox[\textwidth][c]{\hfill\nrl@markinsertBig\hfill}%
    \fi
  }%
  \def\@evenfoot{% empty page
    \parbox[b][\footheight][b]{\textwidth}{\centering%
      %\thepage\\%pcm19jul2019 put a page number on the bottom of empty even pages
      \ifx\nrl@savedmark\@empty\relax%
      \else\makebox[\textwidth][c]{\hfill\nrl@markinsertBig\hfill}%
      \fi
  }}%
}

% define different cleardoublepage behaviors depending on whether a classification marking is present
\def\cleardoublepage{%pcm20jun2016
  \clearpage%
  \if@twoside%
    \ifodd\c@page%
      \relax% do nothing
    \else% even page
      \ifx\nrl@savedmark\@empty
        \thispagestyle{plain}%myheadings
        \setlength{\parindent}{0em}
        \parbox[b][\textheight][t]{\textwidth}{%
          \vspace*{0.21\textheight}%msk16sep2020
          \centering \ifnrl@isclass (U) \fi This page intentionally left blank}%
        \setlength{\parindent}{1.5em}
      \else%
        \thispagestyle{plain}%myheadings
        \setlength{\parindent}{0em}
        \parbox[b][\textheight][t]{\textwidth}{%
          \vspace*{0.21\textheight}%msk16sep2020
          \centering \ifnrl@isclass (U) \fi This page intentionally left blank}%
        \setlength{\parindent}{1.5em}
      \fi%
    \fi%
    \clearpage
  \fi%
}%

% Define special NRL functions and their default settings
% commands needed to make the title page

% used to determine title-page color
\newif\ifnrl@reportisFR\nrl@reportisFRfalse%
\newif\ifnrl@reportisMR\nrl@reportisMRfalse%

% needed for report-kind comparison in both nrlreportnumber & newreportnumber
% TeX cannot easily compare strings unless they are encapsulated within defs.
\def\nrl@FRkind{FR}%
\def\nrl@MRkind{MR}%

% old report-number format
\def\nrlreportnumber#1#2#3{%
\gdef\nrl@reportnumber{NRL/{#1}/{#2}\hspace{1pt}-\hspace{1pt}-\hspace{1pt}{#3}}%
\def\nrl@argkind{#1}%
\ifx\nrl@argkind\nrl@FRkind\nrl@reportisFRtrue% determine whether formal or memo
\else\ifx\nrl@argkind\nrl@MRkind\nrl@reportisMRtrue%
\fi\fi%
}%

% A new report-number format needs a new name to avoid confusion & latex crashes.
\def\newreportnumber#1#2#3#4{%
\gdef\nrl@reportnumber{\mdseries{NRL/{#1}/{#2}\hspace{1pt}-\hspace{1pt}-\hspace{1pt}{#3}/{#4}}}%
\def\nrl@argkind{#2}%
\ifx\nrl@argkind\nrl@FRkind\nrl@reportisFRtrue% determine whether formal or memo
\else\ifx\nrl@argkind\nrl@MRkind\nrl@reportisMRtrue%
\fi\fi%
}%

% set as default only one kind of report number format %pcm14feb2021
%\nrlreportnumber{FR/MR}{code}{xxx-xx}%
\newreportnumber{code}{XX}{year}{xx}%

% enable different dates on title page, documentation page, and page 1 footnote
\def\nrltitlepagedate#1{\gdef\nrl@titlepagedate{#1}}\nrltitlepagedate{Month 00, \the\year}%msk16sep2020 for title page
\def\nrlapprovaldate#1{\gdef\nrl@approvaldate{#1}}\nrlapprovaldate{Month 00, \the\year}%msk16sep2020 footnote for page 1.
\def\nrlreportdate#1{\gdef\nrl@reportdate{\mdseries{#1}}}\nrlreportdate{00-00-\the\year}%msk16sep2020 for documentation page

% WARNING statement
\def\nrl@warningstatement#1{\gdef\nrl@warning{#1}}
\nrl@warningstatement{}% set default to empty warnng

% provide standard warning statements for export control & no forn
% CUI Training Aids: Controlled Unclassified Information Markings, 23 Oct2020, https://www.dodcui.mil
\def\nrlwarning#1{%pcm14feb2021
  %
  % TeX cannot easily compare strings unless they are encapsulated within defs.
  \def\nrl@argkind{#1}%
  \def\nrl@warnkindEX{EX}%
  \def\nrl@warnkindNF{NF}%
  \def\nrl@warnkindTTCP{TTCP}%
  %
  \ifx\nrl@argkind\nrl@warnkindNF\nrl@warningstatement{WARNING --- NOT RELEASABLE TO FOREIGN NATIONALS}%
  %
  \else\ifx\nrl@argkind\nrl@warnkindEX\nrl@warningstatement{%
        WARNING --- This document contains technical data whose export is restricted
        by the Arms Export Control Act (Section 2751 of Title 22, United States
        Code) or the Export Control Reform Act of 2018 (Chapter 58 Sections
        4801-4852 of Title 50, United States Code). Violations of these export laws
        are subject to severe criminal penalties. Disseminate in accordance with
        provisions of DoD Directive 5230.25 and DoD Instruction 2040.02.}
  %
  \else\ifx\nrl@argkind\nrl@warnkindTTCP\nrl@warningstatement{WARNING --- This document contains technical data whose export is restricted by the Arms Export Control Act (Section 2751 of Title 22, United States Code) or the Export Control Reform Act of 2018 (Chapter 58 Sections 4801-4852 of Title 50, United States Code). Violations of these export laws are subject to severe criminal penalties. Disseminate in accordance with provisions of DoD Directive 5230.25 and DoD Instruction 2040.02.\vspace{1em}\\TTCP Disclosure Statement: This document contains information which is provided in confidence to the Governments of Australia, Canada, New Zealand, the United Kingdon, and the United States under The Technical Cooperation Program (TTCP) among these Governments. This document may contain proprietary or commercially valuable information, and repipient Governments will not treat it in any manner likely to prejudice the rights of any owner thereof, including the right to obtain patent or like statutory protection thereof. The Information may be used and disseminated only for evaluation with respect to Defense Purposes within the recipient Governments who will ensure that any other use or disclosure is made only with the prior written consent of each of the above Governments.}
  %
  \else\nrl@warningstatement{#1}% override
  %
  \fi\fi\fi%
}% end nrlwarning

% force a big bold default distribution mark at bottom of title page and SF-298
\def\nrldistributionmark#1{\gdef\nrl@distributionmark{\nrl@markfontBig#1}}
\nrldistributionmark{NOT APPROVED FOR DISTRIBUTION}%msk16sep2020

% force a default distribution statement
\def\nrl@distributionstatement#1{\gdef\nrl@distribution{#1}}
\nrl@distributionstatement{NOT APPROVED FOR DISTRIBUTION}%msk-16sep2020

% define distribution category macro, and set default
\def\nrldistributioncategory#1{\gdef\nrl@distributioncategory{#1}}
\nrldistributioncategory{critical technology}

% provide standard distribution statements for (A,B,C,D,E)
\def\nrldistribution#1{%pcm14feb2021
  %
  \nrldistributionmark{}% turn off bottom mark when any statement (including null) is provided
  %
  % TeX cannot easily compare strings unless they are encapsulated within defs.
  \def\nrl@argkind{#1}%
  \def\nrl@distkindA{A}%
  \def\nrl@distkindB{B}%
  \def\nrl@distkindC{C}%
  \def\nrl@distkindD{D}%
  \def\nrl@distkindE{E}%
  \def\nrl@distkindF{F}%
  \def\nrl@distaddress{Commanding Officer, Naval Research Laboratory, 4555 Overlook Ave SW, Washington DC 20375-5320}
  %
  \ifx\nrl@argkind\nrl@distkindA\nrl@distributionstatement{DISTRIBUTION STATEMENT A. Approved for public release: distribution is unlimited.}%dps-2024-jan-29:copied from DoDI 5230.24, Jan 10, 2023.  Checked against NRL fact sheet 2/2024.
  %
  \else\ifx\nrl@argkind\nrl@distkindB\nrl@distributionstatement{DISTRIBUTION STATEMENT B. Distribution authorized to U.S. Government agencies; \nrl@distributioncategory; \nrl@approvaldate. Other requests for this document must be referred to \nrl@distaddress.}%dps-2024-jan-29:copied from DoDI 5230.24, Jan 10, 2023.  Checked against NRL fact sheet 2/2024.
  %
  \else\ifx\nrl@argkind\nrl@distkindC\nrl@distributionstatement{DISTRIBUTION STATEMENT C. Distribution authorized to U.S. Government agencies and their contractors; \nrl@distributioncategory; \nrl@approvaldate. Other requests for this document must be referred to \nrl@distaddress.}%dps-2024-jan-29:copied from DoDI 5230.24, Jan 10, 2023.  Checked against NRL fact sheet 2/2024.
  %
  \else\ifx\nrl@argkind\nrl@distkindD\nrl@distributionstatement{DISTRIBUTION STATEMENT D. Distribution authorized to Department of Defense and U.S. DoD contractors only; \nrl@distributioncategory; \nrl@approvaldate. Other requests must be referred to \nrl@distaddress.}%dps-2024-jan-29:copied from DoDI 5230.24, Jan 10, 2023.  Updated against NRL fact sheet 2/2024.
  %
  \else\ifx\nrl@argkind\nrl@distkindE\nrl@distributionstatement{DISTRIBUTION STATEMENT E. Distribution authorized to DoD Components only; \nrl@distributioncategory; \nrl@approvaldate. Other requests must be referred to \nrl@distaddress.}%dps-2024-jan-29:copied from DoDI 5230.24, Jan 10, 2023.  Checked against NRL fact sheet 2/2024.
  %
  \else\ifx\nrl@argkind\nrl@distkindF\nrl@distributionstatement{DISTRIBUTION STATEMENT F. Further distribution only as directed by $\left<\mathrm{controlling\ DoD\ office}\right>$ (\nrl@approvaldate) or higher DoD authority.}%
  %
  \else\nrl@distributionstatement{#1}% override
  %
\fi\fi\fi\fi\fi\fi%
}% end nrldisribution

% functions for the classification control box
\newif\ifnrl@isclass\nrl@isclassfalse% will use for testing if doc is classified, replaces uglier series of tests %dps07dec2023
% If any of these macros is set to something non-empty, then document is assumed to be classified
% note: this logic will fail if for some reason one of these macros is set to non-empty and then later set to empty
\def\nrlclassifiedby#1{\gdef\nrl@classifiedby{#1}\if\relax\detokenize{#1}\relax \else \nrl@isclasstrue \fi}\nrlclassifiedby{}% classified by statement
\def\nrlderivedfrom#1{\gdef\nrl@derivedfrom{#1}\if\relax\detokenize{#1}\relax \else \nrl@isclasstrue \fi}\nrlderivedfrom{}% derived from statement%msk16sep2020
\def\nrldeclassifyon#1{\gdef\nrl@declassifyon{#1}\if\relax\detokenize{#1}\relax \else \nrl@isclasstrue \fi}\nrldeclassifyon{}% declassify on statement

% function for the CUI control box
\newif\ifnrl@isCUI\nrl@isCUIfalse% will use for testing if doc is CUI, replaces uglier series of tests %dps07dec2023
\def\nrlCUIcontrolledbyComponent#1{\gdef\nrl@CUIcontrolledbyComponent{#1}\if\relax\detokenize{#1}\relax \else \nrl@isCUItrue \fi}\nrlCUIcontrolledbyComponent{}% controlled by statement%pm25jan2021
\def\nrlCUIcontrolledbyOffice#1{\gdef\nrl@CUIcontrolledbyOffice{#1}\if\relax\detokenize{#1}\relax \else \nrl@isCUItrue \fi}\nrlCUIcontrolledbyOffice{}% controlled by statement%pm25jan2021
\def\nrlCUIcategories#1{\gdef\nrl@CUIcategories{#1}}\nrlCUIcategories{}% list of CUI categories%pm25jan2021
\def\nrlCUIdistribution#1{\gdef\nrl@CUIdistribution{#1}}\nrlCUIdistribution{}% list of CUI distribution%pm25jan2021
\def\nrlCUIdissemenation#1{\gdef\nrl@CUIdissemenation{#1}}\nrlCUIdissemenation{}%pm25jan2021
\def\nrlCUIpoc#1{\gdef\nrl@CUIpoc{#1}\if\relax\detokenize{#1}\relax \else \nrl@isCUItrue \fi}\nrlCUIpoc{}% point of contact%pm25jan2021
\def\nrlCUIrefpoc#1{\gdef\nrl@CUIrefpoc{#1}\if\relax\detokenize{#1}\relax \else \nrl@isCUItrue \fi}\nrlCUIrefpoc{}% point of contact%pm25jan2021
\def\nrlCUIreference#1{\gdef\nrl@CUIreference{#1}}

% default reference
\nrlCUIreference{$\left<\mathrm{CUI\ reference}\right>$}

\def\nrldissemination#1{\gdef\nrl@dissemination{#1}}\nrldissemination{}% dissemination statement
%\nrldissemination{Further dissemination only as directed by Commanding Officer, U.\,S.\ Naval Research Laboratory,\\Washington, DC 20375-5320; \nrl@approvaldate; or higher DoD authority.}

%% commands needed to specify authors & branches
\def\nrl@authorlist{}% init author list
\def\nrlauthorlist#1{\gdef\nrl@authorlist{\mdseries{#1}}} % user-accessible command to override the automatic list
\newcounter{nrl@outsidecounter}% counter to keep track of outside addresses/authors
% defining this here because I want to append any outside addresses to it.  dps_05-2022
\def\nrlorganizationaddress#1{\gdef\nrl@organizationaddress{\mdseries{#1}}}% override in case the automatic generation fails
\nrlorganizationaddress{U.\,S.\ Naval Research Laboratory\\4555 Overlook Ave SW, Washington, DC 20375-5320}

% Note: following Peter's lead I'm simply cutting-and-pasting all the defs for the 2nd through 8th authors and affiliations
% and manually changing the index.  This could be done more compactly by defining macros to create the macros, a la:
%https://tex.stackexchange.com/questions/339651/how-to-create-a-macro-that-creates-other-macros-that-takes-arguments

\def\nrl@branch{}% First NRL Branch Name, init to empty
\def\nrlbranch#1{%
  \gdef\nrl@branch{#1}%
  % update author list w/o annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}\noexpand\@author}
} 
\def\nrl@outsideaddress{}% init to blank
\def\nrloutsideaddress#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddress{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  % \g@addto@macro\nrl@organizationaddress{\\\textsuperscript{\thenrl@outsidecounter}#1}% add w/ superscript to list for SF-298
  % I can't figure out how to use \textsuperscript{} within this edef, but the math form works fine.  I also don't understand the expand stuff.
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$\noexpand\StrSubstitute{#1}{\\}{, }}% update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}\noexpand\@author${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

\def\nrl@authortwo{}% to typeset properly, this needs to be empty when unused
\def\nrlauthortwo#1{\gdef\nrl@authortwo{#1}}
\def\nrl@branchtwo{}
\def\nrlbranchtwo#1{%
  \gdef\nrl@branchtwo{#1}%  
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authortwo}% update author list w/o annotation
}
\def\nrl@outsideaddresstwo{}
\def\nrloutsideaddresstwo#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddresstwo{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$\noexpand\StrSubstitute{#1}{\\}{, }}%update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authortwo${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

\def\nrl@authorthree{}% to typeset properly, this needs to be empty when unused
\def\nrlauthorthree#1{\gdef\nrl@authorthree{#1}}
\def\nrl@branchthree{}
\def\nrlbranchthree#1{%
  \gdef\nrl@branchthree{#1}%  
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorthree}% update author list w/o annotation
}
\def\nrl@outsideaddressthree{}
\def\nrloutsideaddressthree#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddressthree{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$\noexpand\StrSubstitute{#1}{\\}{, }}%update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorthree${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

\def\nrl@authorfour{}% to typeset properly, this needs to be empty when unused
\def\nrlauthorfour#1{\gdef\nrl@authorfour{#1}}
\def\nrl@branchfour{}
\def\nrlbranchfour#1{%
  \gdef\nrl@branchfour{#1}%  
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorfour}% update author list w/o annotation
}
\def\nrl@outsideaddressfour{}
\def\nrloutsideaddressfour#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddressfour{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$#1}%update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorfour${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

\def\nrl@authorfive{}% to typeset properly, this needs to be empty when unused
\def\nrlauthorfive#1{\gdef\nrl@authorfive{#1}}
\def\nrl@branchfive{}
\def\nrlbranchfive#1{%
  \gdef\nrl@branchfive{#1}%  
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorfive}% update author list w/o annotation
}
\def\nrl@outsideaddressfive{}
\def\nrloutsideaddressfive#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddressfive{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$#1}%update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorfive${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

\def\nrl@authorsix{}% to typeset properly, this needs to be empty when unused
\def\nrlauthorsix#1{\gdef\nrl@authorsix{#1}}
\def\nrl@branchsix{}
\def\nrlbranchsix#1{%
  \gdef\nrl@branchsix{#1}%  
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorsix}% update author list w/o annotation
}
\def\nrl@outsideaddresssix{}
\def\nrloutsideaddresssix#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddresssix{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$#1}%update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorsix${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

\def\nrl@authorseven{}% to typeset properly, this needs to be empty when unused
\def\nrlauthorseven#1{\gdef\nrl@authorseven{#1}}
\def\nrl@branchseven{}
\def\nrlbranchseven#1{%
  \gdef\nrl@branchseven{#1}%  
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorseven}% update author list w/o annotation
}
\def\nrl@outsideaddressseven{}
\def\nrloutsideaddressseven#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddressseven{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$#1}%update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authorseven${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

\def\nrl@authoreight{}% to typeset properly, this needs to be empty when unused
\def\nrlauthoreight#1{\gdef\nrl@authoreight{#1}}
\def\nrl@brancheight{}
\def\nrlbrancheight#1{%
  \gdef\nrl@brancheight{#1}%  
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authoreight}% update author list w/o annotation
}
\def\nrl@outsideaddresseight{}
\def\nrloutsideaddresseight#1{% need extra handling to place annotations
  \gdef\nrl@outsideaddresseight{#1}% set variable for later use on title page
  \stepcounter{nrl@outsidecounter}% increment the counter of outside addresses
  \edef\nrl@organizationaddress{\unexpanded\expandafter{\nrl@organizationaddress}\\${}^{\thenrl@outsidecounter}$#1}%update address list w/ annotation
  \edef\nrl@authorlist{\unexpanded\expandafter{\nrl@authorlist}, \noexpand\nrl@authoreight${}^{\thenrl@outsidecounter}$}% update author list w/ annotation
}

% command to indicate an author is deceased (dps 4/2022)
\def\nrl@deceasedtext{} % holds footnote for title page
\def\nrl@deceaseddate{} % holds text for supplemental notes
%\newcommand{\deceased}[1]{%
\def\deceased#1{%
  \textsuperscript{\ensuremath{\dagger}}%
  \gdef\nrl@deceasedtext{\textsuperscript{\ensuremath{\dagger}}Deceased}%
  \gdef\nrl@deceaseddate{\textsuperscript{\ensuremath{\dagger}}Deceased #1}%
%  \nrlsupplementalnotes{\nrl@supplementalnotes,#1}
}


% commands needed for page headers
\def\nrlheadertitle#1{\gdef\nrl@headertitle{#1}}\nrlheadertitle{short title}
\def\nrlheaderauthor#1{\gdef\nrl@headerauthor{#1}}\nrlheaderauthor{author list}

% Title override for the top of page 1. %pcm14feb2021
% Sometimes the formatting of the title page and the first-page title must differ.
% This provides a mechanism to correct the first-page title.
\def\nrlpagetitle#1{\gdef\nrl@pagetitle{\expandafter\MakeUppercase\expandafter{#1}}}\nrlpagetitle{\@title}
% The original version, which caused math to upper-case
% \def\nrlpagetitle#1{\gdef\nrl@pagetitle{\uppercase\expandafter{#1}}}\nrlpagetitle{\@title}

% commands needed to fill in the Report Documentation Page
\def\nrlreporttype#1{\gdef\nrl@reporttype{\mdseries{#1}}}\nrlreporttype{Formal Report}
\def\nrlstartdate#1{\gdef\nrl@startdate{\mdseries{#1}}}\nrlstartdate{00-00-\the\year}
\def\nrlenddate#1{\gdef\nrl@enddate{\mdseries{#1}}}\nrlenddate{00-00-\the\year}
\def\nrlcontractnumber#1{\gdef\nrl@contractnumber{\mdseries{#1}}}\nrlcontractnumber{}
\def\nrlgrantnumber#1{\gdef\nrl@grantnumber{\mdseries{#1}}}\nrlgrantnumber{}
\def\nrlprogramelement#1{\gdef\nrl@programelement{\mdseries{#1}}}\nrlprogramelement{}
\def\nrlprojectnumber#1{\gdef\nrl@projectnumber{\mdseries{#1}}}\nrlprojectnumber{}
\def\nrltasknumber#1{\gdef\nrl@tasknumber{\mdseries{#1}}}\nrltasknumber{}
\def\nrlworkunitnumber#1{\gdef\nrl@workunitnumber{\mdseries{#1}}}\nrlworkunitnumber{}

% moving this up so I can append outside addresses to it
%\def\nrlorganizationaddress#1{\gdef\nrl@organizationaddress{\mdseries{#1}}}\nrlorganizationaddress{U.\,S.\ Naval Research Laboratory\\4555 Overlook Ave SW, Washington, DC 20375-5320}
\def\nrlsponsoraddress#1{\gdef\nrl@sponsoraddress{\mdseries{#1}}}\nrlsponsoraddress{Office of Naval Research\\One Liberty Center\\875 N. Randolph Street, Suite 1425\\ Arlington, VA 22203-1995}
\def\nrlsponsoracronym#1{\gdef\nrl@sponsoracronym{\mdseries{#1}}}\nrlsponsoracronym{ONR}
\def\nrlsponsorreportnumber#1{\gdef\nrl@sponsorreportnumber{\mdseries{#1}}}\nrlsponsorreportnumber{}
%\def\nrlsupplementalnotes#1{\gdef\nrl@supplementalnotes{\mdseries{#1}}}\nrlsupplementalnotes{}
\def\nrlsupplementalnotes#1{\gdef\nrl@supplementalnotes{#1}}\nrlsupplementalnotes{} % defer \mdseries until later so we can test for empty
\def\nrlsubjectterms#1{\gdef\nrl@subjectterms{\mdseries{#1}}}\nrlsubjectterms{}

\def\nrlreportclass#1{\gdef\nrl@reportclass{\mdseries{#1}}}\nrlreportclass{\nrl@savedmark}
\def\nrlabstractclass#1{\gdef\nrl@abstractclass{\mdseries{#1}}}\nrlabstractclass{}
\def\nrlthispageclass#1{\gdef\nrl@thispageclass{\mdseries{#1}}}\nrlthispageclass{}
\def\nrlabstractlimitation#1{\gdef\nrl@abstractlimitation{\mdseries{#1}}}\nrlabstractlimitation{}
%\def\nrlnumpages#1{\gdef\nrl@numpages{#1}}\nrlnumpages{num pages}%pcm19jul2019 revert to this if ztotpages fails
\def\nrlnumpages#1{\gdef\nrl@numpages{\mdseries{#1}}}\nrlnumpages{\ztotpages}%pcm19jul2019 requires package zref-totpages
\def\nrlresponsibleperson#1{\gdef\nrl@responsibleperson{\mdseries{#1}}}\nrlresponsibleperson{}
\def\nrltelephonenumber#1{\gdef\nrl@telephonenumber{\mdseries{#1}}}\nrltelephonenumber{}

% Disable the thanks command that some author might try to use on the title page.
\def\thanks#1{\relax}%pcm20jun2016

% (line 225) combined report & amsdts
\renewcommand\maketitle{\par
  \begingroup
    \renewcommand\thefootnote{\@fnsymbol\c@footnote}%
    \def\@makefnmark{\rlap{\@textsuperscript{\normalfont\@thefnmark}}}%
    \long\def\@makefntext##1{\parindent 1em\noindent
            \hb@xt@1.8em{%
                \hss\@textsuperscript{\normalfont\@thefnmark}}##1}%
    \if@twocolumn
      \ifnum \col@number=\@ne
        \@maketitle
      \else
        \twocolumn[\@maketitle]%
      \fi
    \else
      \newpage
      \global\@topnum\z@   % Prevents figures from going at top of page.
      \@maketitle
    \fi
    \pagenumbering{roman}
    \thispagestyle{myheadings}%pcm20jun2016
  \endgroup\newpage
  \setcounter{footnote}{0}%
  \global\let\maketitle\relax
  \global\let\@maketitle\relax
  \global\let\title\relax
  \global\let\author\relax
  \global\let\date\relax
  \global\let\and\relax
}


% NEW TITLE PAGE PARAMETERS %pcm14feb2021
% Some of these width parameters are needed by the CUI control boxes.

\newlength{\nrl@titlepage@authorsep}% distance between auhor blocks on title page
\setlength\nrl@titlepage@authorsep{2ex}% default for three authors, becomes smaller when more authors.

% Parameters for the size of boxes that hold stuff.
\newlength{\nrl@titlepage@headheight}% controls vertical position of lab name/address & logo
\newlength{\nrl@titlepage@titleheight}% height of space alloted for titles
\newlength{\nrl@titlepage@leftrightheight}% height of author & caveat control boxes
\newlength{\nrl@titlepage@mainboxheight}% title + content excluding the head
\newlength{\nrl@titlepage@mainboxwidth}% width of the left-hand contents box
\newlength{\nrl@titlepage@leftwidth}% width of the left-hand contents box
\newlength{\nrl@titlepage@rightwidth}% width of the right-hand contents box

% Think twice about changing these parameters. They have been tuned
% to handle up to eight divisions/institutions, and huge warning statements.
\setlength\nrl@titlepage@headheight{1.65in}%
\setlength\nrl@titlepage@titleheight     {2.00in}%
\setlength\nrl@titlepage@leftrightheight {6.60in}%
\setlength\nrl@titlepage@mainboxheight   {8.60in}% total=title+leftright
\setlength\nrl@titlepage@mainboxwidth{6.8in}%
\setlength\nrl@titlepage@leftwidth{4.25in}%
\setlength\nrl@titlepage@rightwidth{2.20in}%

\newlength{\nrl@titlepage@movewarnleft}%
\setlength{\nrl@titlepage@movewarnleft}{-\nrl@titlepage@leftwidth}%
\addtolength{\nrl@titlepage@movewarnleft}{-1.09em}% adjust horizontal position to align with the right-hand box

%pcm19jul2019 make a classification control box for the title page
\def\nrl@classcontrolbox{%
  \setlength{\fboxrule}{1pt}% thickness of box outline
  \fbox{%
    \begin{varwidth}{\nrl@titlepage@rightwidth}%
      \raggedright%
      \sf\footnotesize\fontfamily{ptm}%
      \ifx\nrl@classifiedby\@empty\relax\else{Classified by:~\nrl@classifiedby}\\\fi%
      \ifx\nrl@derivedfrom\@empty\relax\else{Derived from:~\nrl@derivedfrom}\\\fi%
      \ifx\nrl@declassifyon\@empty\relax\else{Declassify on:~\nrl@declassifyon}\\\fi%
    \end{varwidth}
}}%

%pcm14feb2021 make a CUI control box for the title page
\def\nrl@CUIcontrolbox{%
  \setlength{\fboxrule}{1pt}% thickness of box outline
  \fbox{%
    \begin{varwidth}{\nrl@titlepage@rightwidth}%
      \raggedright%
      \sf\footnotesize\fontfamily{ptm}%
      \ifx\nrl@CUIcontrolledbyComponent\@empty\relax\else{Controlled by:~\nrl@CUIcontrolledbyComponent}\\\fi%
      \ifx\nrl@CUIcontrolledbyOffice\@empty\relax\else{Controlled by:~\nrl@CUIcontrolledbyOffice}\\\fi%
      \ifx\nrl@CUIcategories\@empty\relax\else{CUI Categories:~\nrl@CUIcategories}\\\fi%
      \ifx\nrl@CUIdistribution\@empty\relax\else{Distribution Statement:~\nrl@CUIdistribution}\\\fi%
      \ifx\nrl@CUIdissemenation\@empty\relax\else{LDC:~\nrl@CUIdissemenation}\\\fi%
      \ifx\nrl@CUIpoc\@empty\relax\else{POC:~\nrl@CUIpoc}\\\fi%
    \end{varwidth}
}}%

%pcm14feb2021 make a CUI control box for the title page
\def\nrl@CUIwarningbox{%
  \setlength{\fboxrule}{1pt}% thickness of box outline
  \fbox{\parbox{\nrl@titlepage@rightwidth}{%
    \sf\footnotesize\fontfamily{ptm}%
This content is classified at the
{\ifx\nrl@savedmark\@empty{$\left<\mathrm{CLASS}\right>$}\else{\nrl@savedmark}\fi}
level and may contain elements of controlled unclassified information (CUI), unclassified, or information classified at a lower level than the overall classification displayed. %
% This sentence removed sometime before 5/2024, per NRL security
% This content shall not be used as a source of derivative classification%
%{\ifx\nrl@CUIreference\@empty{.}\else{; refer instead to \nrl@CUIreference.}\fi}
It must be reviewed for both Classified National Security Information (CNSI) and CUI in accordance with DoDI 5230.09 prior to public release.
% Updated 5/2024 to print nothing when POC is empty
% {\ifx\nrl@CUIrefpoc\@empty{$\left<\mathrm{POC}\right>$}\relax\else{POC:~\nrl@CUIrefpoc.}\fi}
{\ifx\nrl@CUIrefpoc\@empty\relax\else{POC:~\nrl@CUIrefpoc.}\fi}
}}}%


% NEW TITLE PAGE %pcm14feb2021
% NRL Report Title Page revised to include color, eight branches, & CUI markings.
% TIS was considering color, but decided to keep a plain cover with ruled lines.
% The ability to color either the entire page or just the head is retained for future use.
% Color is also useful for visualizing text boxes while adjusting their size & position

%\definecolor{name}{model}{color-spec}
\definecolor{nrl@red}{rgb}{1,0.92,0.92}
\definecolor{nrl@green}{rgb}{0.92,1,0.92}
\definecolor{nrl@blue}{rgb}{0.91,0.93,1}
\definecolor{nrl@cyan}{rgb}{0.85,1,1}
\definecolor{nrl@magenta}{rgb}{1,0.85,1}
\definecolor{nrl@yellow}{rgb}{1,1,0.85}
\definecolor{nrl@sky}{rgb}{0.85,0.95,1}
\definecolor{nrl@tan}{rgb}{1,0.95,0.85}

\def\@maketitle{%
  %
  % Define colors for the FR & MR covers.
  % Needs to be done at runtime so that report type is known.
  \ifnrl@reportisFR\colorlet{nrl@titlepage@color}{nrl@blue}
  \else\ifnrl@reportisMR\colorlet{nrl@titlepage@color}{nrl@yellow}
  \else\colorlet{nrl@titlepage@color}{white}
  \fi\fi%
  %
  % Remove spacing between frame. Needed for colored head & test frames.
  \setlength{\fboxsep}{0pt}%
  \setlength{\fboxrule}{0.1pt}%
  %
  % These next two statements that reset lengths need to be defined here.
  % They neither work at compile time (like defaults),
  % nor when placed inside the tabular environment below.
  % These lengths reduce the vertical space between author blocks when many blocks are present.
  \ifx\nrl@authorfour\@empty\relax\else\setlength\nrl@titlepage@authorsep{1.5ex}\fi%
  \ifx\nrl@authorfive\@empty\relax\else\setlength\nrl@titlepage@authorsep{1.0ex}\fi%
  \ifx\nrl@authorsix\@empty\relax\else\setlength\nrl@titlepage@authorsep{0.9ex}\fi%
  \ifx\nrl@authorseven\@empty\relax\else\setlength\nrl@titlepage@authorsep{0.8ex}\fi%
  \ifx\nrl@authoreight\@empty\relax\else\setlength\nrl@titlepage@authorsep{0.7ex}\fi%
  %
  % move origin to upper-left corner and cover gaps on top & left
  \null\vspace{-1.66in}\hspace{-1.25in}
%
% %%  ENTIRE PAGE
  % Note: the height of this minipage cannot exceed 9.8in without
  % totally messing up the entire layout. The left & right boxes are
  % therefore sized to flow out the bottom of this page.
  % Nuts. But that's the way it is, and I don't know why.
  % \begin{minipage}[position][height][inner-pos]{width}
  %
  \begin{minipage}[b][9.8in][t]{8.5in}% encapsulate the entire title page
    %
    % Optionally color the entire page. A rejected TIS experiment.
    %\pagecolor{nrl@titlepage@color}\afterpage{\nopagecolor}%
    %
    %% HEAD: CLASSIFICATION MARK, LAB NAME/ADDRESS & LOGO
    % Optionally color the head.
    % fcolorbox is provided by the xcolor package.
    {%\fcolorbox{nrl@titlepage@color}{nrl@titlepage@color}{%
    % The height of this minipage controls the vertical position of the horizontal rules.
    \begin{minipage}[b][\nrl@titlepage@headheight][t]{8.5in}%
      %
      % TOP CLASSIFICATION MARK
      % Top mark needs to be printed here, otherwise background images & color patches cover it up.
      % With no mark we have an empty box of known size.
      {%\fbox{% test frame
      \begin{minipage}[b][3.4em][t]{8.5in}
        \ifx\nrl@savedmark\@empty\relax%
        \else\vspace*{2em}\hfill{\nrl@markinsertBig}\hfill\strut%
        \fi%
      \end{minipage}}% end classification mark
      \vspace*{-3.4em}\\% back up over the mark
      %
      % LAB NAME/ADDRESS
      \vfill% shove everything down to the bottom of the box
      \hspace*{1in}% horizontal space before lab name/address
      {%\fbox{% test frame
      \begin{minipage}[b][3em][b]{4in}
      {\sf\bfseries\fontsize{19pt}{19pt}\selectfont{U.\,S.\ Naval Research Laboratory}}%
      \vspace*{1ex}\\
      {\sf\fontsize{13pt}{13pt}\selectfont{Washington, DC 20375-5320}}
      \end{minipage}}% end lab name/address box
      %
      % NRL LOGO
      \hfill% betwen header box and logo shoving logo hard right
      \includegraphics[width=1.5in]{NRL_logo_1C}%
      \hspace*{0.7in} % this controls the horizontal position of the logo
      %
      \vspace*{1.5ex}% adjust height of lab name/address & logo above the head-box bottom
      %
    \end{minipage}}% end lab name/address, logo & horizontal rules
%
%   %% HORIZONTAL & VERTICAL RULES
    % The rules mark a gap between the head & main boxes.
    % Lay down the top pair of horizontal rules
    \vspace*{-2.5ex}\\% adjust height of rules below the head-box bottom
    \rule[0ex]{8.5in}{2.5pt}% draw thick top line
    \vspace*{-2ex}\\% adjust space between rules
    \rule[0ex]{8.5in}{1pt}% draw thin bottom line
    \vspace*{-1pt}\\% close a gap
    %
    \hspace*{1in} % horizontal position of the main box
    %
    \rule{2.5pt}{\nrl@titlepage@mainboxheight}% vertical line
    \hspace*{1ex}%
%
%   %% MAIN BOX: encapsulate title, number, authors, warnings, caveats
%
    {%\fcolorbox{black}{nrl@yellow}{% colored test frame
    \begin{minipage}[b][\nrl@titlepage@mainboxheight][t]{\nrl@titlepage@mainboxwidth}% main box
%
%     %% TITLE & REPORT NUMBER
      {%\fcolorbox{black}{nrl@tan}{% colored test frame
      \begin{minipage}[b][\nrl@titlepage@titleheight][t]{7.0in}%
        \vspace*{4ex}% vertical position of report number
        % The width of this parbox controls the horizontal placement of the report number
        % \parbox{width}{text}% if it needs a height specification, use minipage
        {%\fbox{% test frame
        \parbox{7.0in}{\hfill\sf\fontsize{14pt}{14pt}\selectfont{\nrl@reportnumber}}}\\
        \vfill
        {%\fbox{% test frame
        \parbox{6.5in}{\raggedright\rm\bfseries\Huge{\@title}\vspace*{1ex}}}
      \end{minipage}}\\% end title & report number
      %\vspace*{-\nrl@titlepage@raiseleft}\\
%
%     %% LEFT BOX encapsulate: author, branch, date, warnings, distribution & dissemination
      %{%\fbox{% test frame
      {%\fcolorbox{black}{nrl@cyan}{% test frame
      \begin{minipage}[b][\nrl@titlepage@leftrightheight][t]{\nrl@titlepage@leftwidth}%
        {\normalsize
        \hspace{-1ex}% move the following tabular back left a little bit
          \begin{tabular}[t]{l}
            %
            % author and branch boxes.
            \vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\@author}%
            %
            \vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@branch}%
            %
            % other authors & branches
            \ifx\nrl@authortwo\@empty\relax\else\vspace*{3\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\nrl@authortwo}\fi%
            %
            \ifx\nrl@branchtwo\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@branchtwo}\fi%
            %
            \ifx\nrl@outsideaddresstwo\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@outsideaddresstwo}\fi%
            %
            \ifx\nrl@authorthree\@empty\relax\else\vspace*{3\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\nrl@authorthree}\fi%
            %
            \ifx\nrl@branchthree\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@branchthree}\fi%
            %
            \ifx\nrl@outsideaddressthree\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@outsideaddressthree}\fi%
            %
            \ifx\nrl@authorfour\@empty\relax\else\vspace*{3\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\nrl@authorfour}\fi%
            %
            \ifx\nrl@branchfour\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@branchfour}\fi%
            %
            \ifx\nrl@outsideaddressfour\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@outsideaddressfour}\fi%
            %
            \ifx\nrl@authorfive\@empty\relax\else\vspace*{3\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\nrl@authorfive}\fi%
            %
            \ifx\nrl@branchfive\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@branchfive}\fi%
            %
            \ifx\nrl@outsideaddressfive\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@outsideaddressfive}\fi%
            %
            \ifx\nrl@authorsix\@empty\relax\else\vspace*{3\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\nrl@authorsix}\fi%
            %
            \ifx\nrl@branchsix\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@branchsix}\fi%
            %
            \ifx\nrl@outsideaddresssix\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@outsideaddresssix}\fi%
            %
            \ifx\nrl@authorseven\@empty\relax\else\vspace*{3\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\nrl@authorseven}\fi%
            %
            \ifx\nrl@branchseven\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@branchseven}\fi%
            %
            \ifx\nrl@outsideaddressseven\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@outsideaddressseven}\fi%
            %
            \ifx\nrl@authoreight\@empty\relax\else\vspace*{3\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\large\scshape\nrl@authoreight}\fi%
            %
            \ifx\nrl@brancheight\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@brancheight}\fi%
            %
            \ifx\nrl@outsideaddresseight\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\normalsize\itshape\nrl@outsideaddresseight}\fi%
            %
            \ifx\nrl@deceasedtext\@empty\relax\else\vspace*{1\nrl@titlepage@authorsep}\\%
            \parbox{\nrl@titlepage@leftwidth}{\rm\small\nrl@deceasedtext}\fi%
          \end{tabular}}%
        %
        \vfill% center the date vertically between division name & caveats
        {\rm\large\nrl@titlepagedate}
        \vfill%\rule{1em}{1ex}%
        %
        % warning, distribution & dissemination statements %pcm09apr2021
        \ifx\nrl@warning\@empty\relax\else%
          \parbox{\nrl@titlepage@mainboxwidth}%
            {\sf\footnotesize\fontfamily{ptm}\nrl@warning}% WARNING
          \vspace*{1em}\\\fi%
        %
        \ifx\nrl@distribution\@empty\relax\else%
          \parbox{\nrl@titlepage@mainboxwidth}%
            {\sf\footnotesize\fontfamily{ptm}\nrl@distribution}% DISTRIBUTION
          \vspace*{1em}\\\fi%
        %
        \ifx\nrl@dissemination\@empty\relax\else%
          \parbox{\nrl@titlepage@mainboxwidth}%
            {\sf\footnotesize\fontfamily{ptm}\nrl@dissemination}% DISSEMINATION
          \vspace*{1em}\\\fi%
        %
        \vspace*{-1em}% erase the previous 1em
      \end{minipage}}% end left box: title, author, date & approval
%
%     %% RIGHT BOX encapsulate classification & CUI control boxes
      \hspace*{1em}% add some horizontal space between the warnings and the author list
      %{%\fbox{% test frame
      {%\fcolorbox{black}{nrl@magenta}{% test frame
      \begin{minipage}[b][\nrl@titlepage@leftrightheight][b]{\nrl@titlepage@rightwidth}%
        %
        \raggedright% align caveat boxes along their left edges
        %
        % set box-frame parameters for CUI caveats
        \setlength{\fboxsep}{2.5pt}% spacing between frame & text
        \setlength{\fboxrule}{1pt}%
        %
        % CLASSIFY & declassify control statements
        \ifnrl@isclass\nrl@classcontrolbox\vspace*{1em}\\\fi%
        % old version  
        % \ifx\nrl@classifiedby\@empty%
        %   \ifx\nrl@derivedfrom\@empty%
        %     \ifx\nrl@declassifyon\@empty%
        %     \else\nrl@classcontrolbox\vspace*{1em}\\\fi%
        %   \else\nrl@classcontrolbox\vspace*{1em}\\\fi%
        % \else\nrl@classcontrolbox\vspace*{1em}\\\fi%
        %
        % CUI control box
        \ifnrl@isCUI\nrl@CUIcontrolbox\vspace*{1em}\\\fi%
        % \ifx\nrl@CUIcontrolledbyComponent\@empty%
        %   \ifx\nrl@CUIcontrolledbyOffice\@empty%
        %   \else\nrl@CUIcontrolbox\vspace*{1em}\\\fi%
        % \else\nrl@CUIcontrolbox\vspace*{1em}\\\fi%
        %
        % CUI warning box for classified material
        \ifnrl@isclass\ifnrl@isCUI\nrl@CUIwarningbox\vspace*{1em}\\\fi\fi%
        % \ifx\nrl@classifiedby\@empty%
        %   \ifx\nrl@derivedfrom\@empty%
        %     \ifx\nrl@declassifyon\@empty%
        %     \else\nrl@CUIwarningbox\vspace*{1em}\\\fi%
        %   \else\nrl@CUIwarningbox\vspace*{1em}\\\fi%
        % \else\nrl@CUIwarningbox\vspace*{1em}\\\fi%
        %
        % PHANTOM warning, distribution & dissemination statements: %pcm09apr2021
        % This phantom text serves to measure the vertical height of the warnings
        % that are printed by the left-hand box so that the CUI boxes may be stacked on top.
        %
        % phantom warning, distribution & dissemination statements %pcm09apr2021
        \ifx\nrl@warning\@empty\relax\else%
          \vphantom{\parbox{\nrl@titlepage@mainboxwidth}%
            {\sf\footnotesize\fontfamily{ptm}\nrl@warning}}% phantom WARNING
          \vspace*{1em}\\\fi%
          %
        \ifx\nrl@distribution\@empty\relax\else%
          \vphantom{\parbox{\nrl@titlepage@mainboxwidth}%
            {\sf\footnotesize\fontfamily{ptm}\nrl@distribution}}% phantom DISTRIBUTION
          \vspace*{1em}\\\fi%
          %
        \ifx\nrl@dissemination\@empty\relax\else%
          \vphantom{\parbox{\nrl@titlepage@mainboxwidth}%
            {\sf\footnotesize\fontfamily{ptm}\nrl@dissemination}}% phantom DISSEMINATION
          \vspace*{1em}\\\fi%
          %
        \vspace*{-3.1pt}% adjust vertical position to align with the right-hand box
      \end{minipage}}% end right box:
    \end{minipage}}% end main box
%
%   % HORIZONTAL LINE along the bottom
    \vspace*{-2.3ex}\\% postion of the bottom line
    \hspace*{1.04in}% it needs a little extra indentation
    \rule{7.5in}{2.5pt}% draw the thick bottom line
%
  \end{minipage}% end entire page
%
}% end def maketitle


% disable resetting the footnote counter with each new chapter
% (must follow \LoadClass{report}, which enabled the resetting)
\counterwithout{footnote}{chapter}%pcm20jun16

% initialize appendix indicator to false
\newif\ifapp     \appfalse

\renewcommand\chapter{\vskip 10\p@ % space disappears at top of page
                    \global\@topnum\z@ % Prevents figures from going at top of page.
                    \secdef\@chapter\@schapter}

\def\@chapter[#1]#2{\ifnum \c@secnumdepth >\m@ne
                         %\stepcounter{chapter}% moved below pcm01oct13
                         \typeout{\@chapapp\space\thechapter.}%
                         \ifapp %%% Appendix
                           % The initial clearpage flushes floats from the previous section before a new page and section are started.
                           % Without it, floats can appear on an unumbered page or in the next section.

                           % The formal-report style calls for each appendix to start on a new right-hand page, which implies twoside.
                           % Curiously, it does not appear to require the same of regular chapters.  So we need to enforce openright-type
                           % behavior for the appendices regardless of the openright/openany options.
                           % This behavior is undesired for oneside documents (some memo reports, for example), but as the oneside option
                           % turns \cleardoublepage into just \clearpage we shouldn't need to do anything clever here.
                         \cleardoublepage\thispagestyle{plain} % new page, and change header to just page number at bottom
                           \setcounter{equation}{0}
                           \setcounter{figure}{0}
                           \setcounter{table}{0}
                           \stepcounter{chapter} %pcm01oct13 I don't know why this works, or needs to be here.
                           % If placed at the beginning, the last page of each appendix wrongly gets labeled with the next appendix letter.
                           % Do not reset or restyle appendix page numbers here. TIS wants them numbered in sequence with the main text.
                           \vspace*{4.5mm}
                         \else %%% Chapters
                           \stepcounter{chapter}%pcm01oct13
                           % For regular chapters, the default is to start mid-page, with the exception of the first chapter, which starts
                           % on a new odd-numbered page in two-side mode.  The openany option forces a new page, while the
                           % openright option forces chapters to start on a new right-side page (if twosided is true).  It would seem
                           % based on the prior template that other than the opening chapter, the headings are not changed when a new
                           % chapter begins.
                           \if@openany\clearpage\thispagestyle{headings}\fi%pcm08mar16
                           \if@openright\cleardoublepage\thispagestyle{headings}\fi%pcm08mar16 %pcm29jul2016 changed empty to plain
                           \ifnum \c@chapter = \@ne% if first chapter
                             %\if@twoside\cleardoublepage\fi% clear to odd starting page (page 1)
                             \cleardoublepage %dps21jun2024: for twoside, adds any blank pages before page 1.  For oneside, probably does nothing.
                             \thispagestyle{plain}%pcm29jul2016 changed empty to plain
                             \def\footnoterule{\kern-3\p@ \hrule width 54pt \kern 2.6\p@} % for date approved footnote (see nrl.sty & report.cls)
                             \setcounter{page}{1}
                             \pagenumbering{arabic}  %%% start arabic page numbering
                             \vspace*{4.5mm}
                           \fi
                         \fi
                    \fi
                    \chaptermark{#1}%
                    \@makechapterhead{\MakeTextUppercase{#2}}%pcm24oct13 upcase chapter headings with a smarter function than MakeUppercase
                    \@afterheading
                    %pcm03jul12 refstepcounter and addcontentsline need to be delayed until after
                    % makechapterhead so that the correct page number is listed in the contents
                    \addtocounter{chapter}{-1}% decrement the previous stepcounter
                    \refstepcounter{chapter}% now reincrement and register the counter and page number
                    \ifnum \c@secnumdepth >\m@ne
                      \ifapp %%% Appendix
                        \phantomsection\addcontentsline{toc}{chapter}{\protect \nrl@markU APPENDIX \numberline{\thechapter---}{#1}}%pcm24oct13 the author needs to use initial caps in appendix titles
                      \else  %%% Chapters
                      % \phantomsection\addcontentsline{toc}{chapter}{\protect{\numberline{\thechapter.}\texorpdfstring{\expandafter\MakeUppercase\expandafter{#1}}{#1}}}%DPS06dec2022 fixed this
                      % DPS11mar2023 confused about my "fix" above; the \expandafter's don't seem to do anything.  And in LaTeX 2022, the line below breaks as a superfluous '[]' is added after \MakeUppercase in the toc, which causes a compile error on the second pass.
                        % The error is in microtype.sty, now fixed: https://github.com/schlcht/microtype/issues/29
                        \phantomsection\addcontentsline{toc}{chapter}{\protect{\numberline{\thechapter.}\texorpdfstring{\MakeUppercase{#1}}{#1}}}
                      \fi
                      \else
                      % Need to fix this one to use \MakeUppercase also, but need a case which actually exercises it first.
                      \phantomsection\addcontentsline{toc}{chapter}{\uppercase{#1}}%pcm29jul2016 added phantomsection everywhere
                    \fi
                    \pagestyle{headings}% header style for remaining pages of the paper
}%

\def\psnrl@reportfirstpage{\let\@mkboth\@gobbletwo
     \let\@oddhead\@empty\def\@oddfoot{\reset@font\hfil\thepage
     \hfil}\let\@evenhead\@empty\let\@evenfoot\@oddfoot}

% approval date from nrl.sty
\def\@makechapterhead#1{%
 % \vspace*{0\p@}
  {\parindent \z@ \raggedright \normalfont
    \interlinepenalty\@M
    \ifapp
      \centering \large \bfseries \@chapapp\space \thechapter
      \par\nobreak
      \MakeTextUppercase{#1}\par\nobreak%pcm24oct13 force appendix titles to uppercase
    \else
      \ifnum \c@chapter = \@ne
        \vspace*{2mm}
        %
        % newlines in \MakeTextUppercase{\@title} crash here. %pcm14feb2021
        % uppercasing of the page title must be done in \nrl@pagetitle, otherwise it fails
        % because it's all caps, use 13pt with a little extra interline spacing
        {\centering\bfseries\fontsize{13pt}{17pt}\selectfont\nrl@pagetitle\par}%pcm14feb2021
        %
        \vskip\baselineskip
        \enlargethispage{10pt}% move footnote down
        \def\thefootnote{\mbox{}}
        \footnotetext[0]{\hspace{-6mm} {Manuscript approved \nrl@approvaldate{.}}}
        \def\thefootnote{\arabic{footnote}}
      \fi
      \normalsize \bfseries \thechapter. \hspace{0.5em} {#1}\par\nobreak
    \fi
%    \vskip 5\p@
  }}
\def\@schapter#1{\if@twocolumn
                   \@topnewpage[\@makeschapterhead{#1}]%
                 \else
                   \@makeschapterhead{#1}%
                   \@afterheading
                 \fi}
\def\@makeschapterhead#1{%
  {\parindent \z@ \raggedright \normalfont
    \interlinepenalty\@M
    \normalsize \bfseries  #1\par\nobreak
%    \vskip 0\p@
  }}

% (line 414)
\renewcommand\section{\@startsection{section}{1}{\z@}
  {.1ex \@plus .5ex \@minus .2ex}
  {.1ex \@plus.2ex}
  {\normalsize\bfseries}}
\renewcommand\subsection{\@startsection{subsection}{2}{\z@}
  {.1ex\@plus .5ex \@minus .2ex}
  {.1ex \@plus .2ex}
  {\normalsize\itshape}}
% indent the next section using parindent %pcm01oct13
\renewcommand\subsubsection{\@startsection{subsubsection}{3}{\parindent}
  {.1ex\@plus .5ex \@minus .2ex}
  {.1ex \@plus .2ex}
  {\normalsize\bfseries}}
% run the next two section levels in with the paragraph %pcm24oct13
% @starsection cannot be used here because it won't append the em dashes properly
\renewcommand{\paragraph}[1]{{\normalsize\itshape{#1} ---}}
\renewcommand{\subparagraph}[1]{{\normalsize\itshape{#1} ---}}

% (line 5610) of latex.ltx
% turn on indentation at start of section
\def\@startsection#1#2#3#4#5#6{%
  \if@noskipsec \leavevmode \fi
  \par
  \@tempskipa #4\relax
  \@afterindenttrue
  \ifdim \@tempskipa <\z@
    \@tempskipa -\@tempskipa %\@afterindentfalse %% MSKNRL
  \fi
  \if@nobreak
    \everypar{}%
  \else
    \addpenalty\@secpenalty\addvspace\@tempskipa
  \fi
  \@ifstar
    {\@ssect{#3}{#4}{#5}{#6}}%
    {\@dblarg{\@sect{#1}{#2}{#3}{#4}{#5}{#6}}}}

% change appendix numbering style (modified from: chngcntr.sty)
%\renewcommand{\c@t@sin}[2]{%
%  \@ifbothc@t@s{chngcntr}{#1}{#2}{\@addtoreset{#1}{#2}%
%    \@namedef{the#1}{\@nameuse{the#2}\arabic{#1}}}}% removed printing a dot before \arabic %pcm20jun16

% (line 529)
\renewcommand\appendix{%\par
  \apptrue			%% MSKNRL
  \setcounter{chapter}{0}%
  \setcounter{section}{0}%
  \counterwithin{footnote}{chapter}% enable footnote counter resets within appendices %pcm20jun16
  \gdef\@chapapp{\appendixname}%
  \gdef\thechapter{\@Alph\c@chapter}%
  \renewcommand\theequation{\thechapter\@arabic\c@equation}%% MSKNRL
  \renewcommand\thefigure{\thechapter\@arabic\c@figure}%% MSKNRL
  \renewcommand\thetable{\thechapter\@arabic\c@table}%% MSKNRL
  }
% (line 537)
\renewcommand\theequation{\@arabic\c@equation}
\renewcommand\thefigure{\@arabic\c@figure}
\renewcommand\thetable{\@arabic\c@table}%pcm24oct13 tables are to be numbered consecutively

%%%%%%
% set figure and table caption font sizes - pcm04feb16
\def\fig@capsize{\footnotesize}
\def\tbl@capsize{\normalsize}
\def\tbl@itemsize{\normalsize}
\def\tbl@notesize{\footnotesize}

\newif\ifdoing@figure \doing@figuretrue

% These two widths get compared for centering decisions. %pcm27feb2021
\newlength{\nrl@capwidth}% print width of a caption
\newlength{\nrl@caplength}% length of the users caption text

%% Some authors habitually use LaTeX figure and table environments.
%% Asking them to redo all of their figures & tables is awkward.
%% Make LaTeX captions behave like NRL figure and table captions.
%% The LaTeX captions must have a fixed width because they
%% cannot know the size of the figures/tables that they label.
\def\latex@makefigcaption#1#2{% pcm27feb2021
  \fig@capsize\centering% center caption box on the page
  \vskip\abovecaptionskip% add space between figure & caption
  \settowidth{\nrl@caplength}{#1---#2}% get length of caption text
  \setlength{\nrl@capwidth}{0.7\textwidth}% set width of caption
  \parbox{\nrl@capwidth}{%
    \hyphenpenalty10000\exhyphenpenalty10000% suppress hyphens
    \ifdim\nrl@caplength<2\nrl@capwidth%
      \centering#1---#2%
    \else%
      #1---#2%
    \fi%
  }%
}%

\def\latex@maketblcaption#1#2{% pcm27feb2021
  \tbl@capsize\centering% center caption box on the page
  \settowidth{\nrl@caplength}{#1---#2}% get length of caption text
  \setlength{\nrl@capwidth}{0.7\textwidth}% set width of caption
  \parbox{\nrl@capwidth}{%
    \hyphenpenalty10000\exhyphenpenalty10000% suppress hyphens
    \ifdim\nrl@caplength<2\nrl@capwidth%
      \centering#1---#2%
    \else%
      #1---#2%
    \fi%
  }%
  \vspace*{-4pt}% adjust space between caption & table to mimic nrltable %pcm27feb2021
  \vskip\belowcaptionskip% add space between caption & table
}%

\def\LT@makecaption#1#2#3{% longtable caption modification - function from longtable.sty %pcm01jul2021
  \LT@mcol\LT@cols c{\hbox to\z@{\hss\parbox[t]\LTcapwidth{%
    \sbox\@tempboxa{#1{#2---}#3}%
    \ifdim\wd\@tempboxa>\hsize
      #1{#2---}#3%
    \else
      \hbox to\hsize{\hfil\box\@tempboxa\hfil}%
    \fi
    \endgraf\vskip\baselineskip}%
  \hss}}}

\def\nrl@makefigcaption#1#2{%
  \fig@capsize%
  \vskip\abovecaptionskip% add space between figure and caption
  #1---#2% nrlfigure environment handles centering
}

\def\nrl@maketblcaption#1#2{%
  \tbl@capsize%
  #1---#2% nrltable environment handles centering
  \vskip\belowcaptionskip% add space between caption and table
}

%%%%%%
% (line 594)
\renewcommand\@pnumwidth{1.5em}
\renewcommand\@tocrmarg{2.55em}
\renewcommand\@dotsep{0.5}
\setcounter{tocdepth}{1}
% (line 598)  make centered section heading
\renewcommand\tableofcontents{%
    \if@twocolumn
      \@restonecoltrue\onecolumn
    \else
      \@restonecolfalse
    \fi
    \thispagestyle{plain}\cleardoublepage\thispagestyle{plain}%pcm29jul2016 changed empty to plain
    \pagenumbering{roman}
    \setcounter{page}{3}%msk16sep2020 also see \nrlabstract
    \vspace*{4.5mm}
    \chapter*{\large \centering \contentsname}%
    \vskip 6mm
    \parskip  0pt
    \@starttoc{toc}%
    \if@restonecol\twocolumn\fi
    \setReportMargins% reset parskip
    \clearpage% flush page numbers pcm24jun14
    }
% (line 625) extended based on genthesis
\renewcommand*\l@chapter[2]{%
  \ifnum \c@tocdepth >\m@ne
    \addpenalty{-\@highpenalty}%
    \vskip 1.0em% \@plus\p@
    \setlength\@tempdima{1.5em}%
    \begingroup
      \parindent \z@ \rightskip \@pnumwidth
      \parfillskip -\@pnumwidth
      \leavevmode
      \advance\leftskip\@tempdima
      \hskip -\leftskip
      {\@fmttocchapter{#1}}\nobreak
      \leaders\hbox{$\m@th
        \mkern \@dotsep mu\hbox{.}\mkern \@dotsep%
        mu$}\hfil
      \nobreak
      \hb@xt@\@pnumwidth{\hfil \@fmttocchapterpage{#2}}\par%
      \penalty\@highpenalty
    \endgroup
  \fi}
% (line 640) extended based on genthesis, numbers from nrl.sty
\renewcommand*\l@section[2]{%
  \@dottedtocline{1}{1.5em}{2.3em}{\@fmttocsection{#1}}%
                                  {\@fmttocsectionpage{#2}}}
\renewcommand*\l@subsection[2]{%
  \@dottedtocline{2}{2.6em}{2.8em}{\@fmttocsubsection{#1}}%
                                  {\@fmttocsubsectionpage{#2}}}
\renewcommand*\l@subsubsection[2]{%
  \@dottedtocline{3}{3.8em}{3.2em}{\@fmttocsubsubsection{#1}}%
                                  {\@fmttocsubsubsectionpage{#2}}}
\renewcommand*\l@paragraph[2]{%
  \@dottedtocline{4}{7em}{4.1em}{\@fmttocparagraph{#1}}%
                               {\@fmttocparagraphpage{#2}}}
\renewcommand*\l@subparagraph[2]{%
  \@dottedtocline{5}{10em}{5em}{\@fmttocsubparagraph{#1}}%
                               {\@fmttocsubparagraphpage{#2}}}
% from genthesis
\newcommand\@fmttocchapter[1]{#1}
\newcommand\@fmttocchapterpage[1]{\normalfont \normalcolor #1}
\newcommand\@fmttocsection[1]{#1}
\newcommand\@fmttocsectionpage[1]{\normalfont \normalcolor #1}
\newcommand\@fmttocsubsection[1]{\textit{#1}}
\newcommand\@fmttocsubsectionpage[1]{\normalfont \normalcolor #1}
\newcommand\@fmttocsubsubsection[1]{\textit{#1}}
\newcommand\@fmttocsubsubsectionpage[1]{\normalfont \normalcolor #1}
\newcommand\@fmttocparagraph[1]{\textit{#1}}
\newcommand\@fmttocparagraphpage[1]{\normalfont \normalcolor #1}
\newcommand\@fmttocsubparagraph[1]{\textit{#1}}
\newcommand\@fmttocsubparagraphpage[1]{\normalfont \normalcolor #1}

\renewcommand\listoffigures{%
    \if@twocolumn
      \@restonecoltrue\onecolumn
    \else
      \@restonecolfalse
    \fi
    \thispagestyle{plain} \clearpage% add to back of contents page pcm4may15
    \vspace*{4.5mm}
    \chapter*{\large \centering \listfigurename}%
    \vskip 1.0em
    \@starttoc{lof}%
    \if@restonecol\twocolumn\fi
    \setReportMargins% reset parskip
    \clearpage% flush page numbers pcm24jun14
    }

\renewcommand\listoftables{%
    \if@twocolumn
      \@restonecoltrue\onecolumn
    \else
      \@restonecolfalse
    \fi
    \thispagestyle{plain} \clearpage% add to back of contents page pcm4may15
    \vspace*{4.5mm}
    \chapter*{\large \centering \listtablename}%
    \vskip 1.0em
    \@starttoc{lot}%
    \if@restonecol\twocolumn\fi
    \setReportMargins% reset parskip
    \clearpage% flush page numbers pcm24jun14
    }

% bibliography numbering format
\def\@biblabel#1{{\ifapp {\thechapter#1.} \else {#1.} \fi}\hfill}

% Appendix citation format pcm01oct13
% adapted from texlive/2012/texmf-dist/tex/latex/bibunits/bibunits.sty
% redefine startbibunit to fix appendix citation format
\def\@startbibunit{%
  \global\let\@startbibunitorrelax\relax
  \global\let\@finishbibunit\@finishstartedbibunit
  \global\advance\@bibunitauxcnt 1
  \if@filesw
    {\endlinechar-1
    \@input{\@bibunitname.aux}}%
    \immediate\openout\@bibunitaux\@bibunitname.aux
    \immediate\write\@bibunitaux{\string\bibstyle{\@localbibstyle}}%
    % add the following lines to make appendix citations look like [A1] or [B3,B4] etc. pcm01oct13
    \ifapp %%% Appendix
      \immediate\write\@bibunitaux{\string\bibpunct[,]{\string\,[\thechapter}{]}{,\string\,\thechapter\string\hspace{-3pt}}{n}{,}{,}}%
    \else  %%% Chapters
      \immediate\write\@bibunitaux{\string\bibpunct[,]{\string\,[}{]}{,}{n}{,}{,}}%
    \fi
  \fi
}

\def\nrl@chapterhead#1{%
  {
    \if@openany\ifapp\else\clearpage\thispagestyle{headings}\fi\fi%
    \if@openright\ifapp\else\clearpage\thispagestyle{plain}\cleardoublepage\thispagestyle{headings}\fi\fi%
    \parindent \z@ \raggedright \normalfont
    \interlinepenalty\@M
    \vspace{1em}
    \normalsize \bfseries \MakeTextUppercase{#1}\par\nobreak
    \@afterheading
  }}
\renewcommand\bibsection{%
  \nrl@chapterhead{\bibname}%
}%

% The original nrlreport.cls inherited from Michael Kluskens breaks appendix citation numbering
% Instead use version from natbib.sty modified to add "REFERENCES" to table-of-contents
\renewenvironment{thebibliography}[1]{%
 \bibsection
 \parindent\z@
 \bibpreamble
 \bibfont
 \list{\@biblabel{\the\c@NAT@ctr}}{\@bibsetup{#1}\global\c@NAT@ctr\z@}%
 \ifNAT@openbib
   \renewcommand\newblock{\par}%
 \else
   \renewcommand\newblock{\hskip .11em \@plus.33em \@minus.07em}%
 \fi
 \sloppy\clubpenalty4000\widowpenalty4000
 \sfcode`\.\@m
 \let\NAT@bibitem@first@sw\@firstoftwo
    \let\citeN\cite \let\shortcite\cite
    \let\citeasnoun\cite
%
    \ifapp \else % do not add appendix references to contents	%pcm02jul12
    \phantomsection\addcontentsline{toc}{chapter}{\bibname} % add references to contents %pcm29jul2016 added phantomsection
    \fi
}{%
 \bibitem@fin
 \bibpostamble
 \def\@noitemerr{%
  \PackageWarning{natbib}{Empty `thebibliography' environment}%
 }%
 \endlist
 \bibcleanup
}%


%pcm13nov14
% adapted from texlive/2012/texmf-dist/tex/latex/bibunits/natbib.sty
% change the hyphen in appendices to include the appendix letter when concatenating consecutive citations.
% this next long mess does only that!
\def\NAT@citexnum[#1][#2]#3{%
  \NAT@reset@parser
  \NAT@sort@cites{#3}%
  \NAT@reset@citea
  \@cite{\def\NAT@num{-1}\let\NAT@last@yr\relax\let\NAT@nm\@empty
    \@for\@citeb:=\NAT@cite@list\do
    {\@safe@activestrue
     \edef\@citeb{\expandafter\@firstofone\@citeb\@empty}%
     \@safe@activesfalse
     \@ifundefined{b@\@citeb\@extra@b@citeb}{%
       {\reset@font\bfseries?}
        \NAT@citeundefined\PackageWarning{natbib}%
       {Citation `\@citeb' on page \thepage \space undefined}}%
     {\let\NAT@last@num\NAT@num\let\NAT@last@nm\NAT@nm
      \NAT@parse{\@citeb}%
      \ifNAT@longnames\@ifundefined{bv@\@citeb\@extra@b@citeb}{%
        \let\NAT@name=\NAT@all@names
        \global\@namedef{bv@\@citeb\@extra@b@citeb}{}}{}%
      \fi
      \ifNAT@full\let\NAT@nm\NAT@all@names\else
        \let\NAT@nm\NAT@name\fi
      \ifNAT@swa
       \@ifnum{\NAT@ctype>\@ne}{%
        \@citea
        \NAT@hyper@{\@ifnum{\NAT@ctype=\tw@}{\NAT@test{\NAT@ctype}}{\NAT@alias}}%
       }{%
        \@ifnum{\NAT@cmprs>\z@}{%
         \NAT@ifcat@num\NAT@num
          {\let\NAT@nm=\NAT@num}%
          {\def\NAT@nm{-2}}%
         \NAT@ifcat@num\NAT@last@num
          {\@tempcnta=\NAT@last@num\relax}%
          {\@tempcnta\m@ne}%
         \@ifnum{\NAT@nm=\@tempcnta}{%
          \@ifnum{\NAT@merge>\@ne}{}{\NAT@last@yr@mbox}%
         }{%
           \advance\@tempcnta by\@ne
           \@ifnum{\NAT@nm=\@tempcnta}{%
             \ifx\NAT@last@yr\relax
               \def@NAT@last@yr{\@citea}%
             \else
               \ifapp %%% Appendix
                 \def@NAT@last@yr{--\thechapter\NAT@penalty}%pcm13nov14
               \else  %%% Chapters
                 \def@NAT@last@yr{--\NAT@penalty}%
               \fi
             \fi
           }{%
             \NAT@last@yr@mbox
           }%
         }%
        }{%
         \@tempswatrue
         \@ifnum{\NAT@merge>\@ne}{\@ifnum{\NAT@last@num=\NAT@num\relax}{\@tempswafalse}{}}{}%
         \if@tempswa\NAT@citea@mbox\fi
        }%
       }%
       \NAT@def@citea
      \else
        \ifcase\NAT@ctype
          \ifx\NAT@last@nm\NAT@nm \NAT@yrsep\NAT@penalty\NAT@space\else
            \@citea \NAT@test{\@ne}\NAT@spacechar\NAT@mbox{\NAT@super@kern\NAT@@open}%
          \fi
          \if*#1*\else#1\NAT@spacechar\fi
          \NAT@mbox{\NAT@hyper@{{\citenumfont{\NAT@num}}}}%
          \NAT@def@citea@box
        \or
          \NAT@hyper@citea@space{\NAT@test{\NAT@ctype}}%
        \or
          \NAT@hyper@citea@space{\NAT@test{\NAT@ctype}}%
        \or
          \NAT@hyper@citea@space\NAT@alias
        \fi
      \fi
     }%
    }%
      \@ifnum{\NAT@cmprs>\z@}{\NAT@last@yr}{}%
      \ifNAT@swa\else
        \@ifnum{\NAT@ctype=\z@}{%
          \if*#2*\else\NAT@cmt#2\fi
        }{}%
        \NAT@mbox{\NAT@@close}%
      \fi
  }{#1}{#2}%
}%


% (line 723)
\renewcommand\contentsname{\nrl@markU CONTENTS}
\renewcommand\listfigurename{\nrl@markU FIGURES}
\renewcommand\listtablename{\nrl@markU TABLES}
\renewcommand\bibname{\nrl@markU REFERENCES}
\renewcommand\figurename{Fig.}% marking is in the caption itself
\renewcommand\tablename{Table}% marking is in the caption itself
\renewcommand\appendixname{\nrl@markU Appendix}
% from amsdtx.cls
\def\@removefromreset#1#2{\let\@tempb\@elt
   \expandafter\let\expandafter\@tempa\csname c@#1\endcsname
   \def\@elt##1{\expandafter\ifx\csname c@##1\endcsname\@tempa\else
         \noexpand\@elt{##1}\fi}%
   \expandafter\edef\csname cl@#2\endcsname{\csname cl@#2\endcsname}%
   \let\@elt\@tempb}
\@removefromreset{equation}{chapter}
\@removefromreset{figure}{chapter}
\@removefromreset{table}{chapter}
% Acknowledgments %pcm08feb16
\newenvironment{acknowledgments}{%
  \apptrue% temporarily turn off openright for acknowledgments
  \nrl@chapterhead{\acknowledgmentsname}%
  \appfalse
  \par
  \phantomsection\addcontentsline{toc}{chapter}{\acknowledgmentsname}%pcm29jul2016 added phantomsection
 }{\par}
\def\acknowledgmentsname{\nrl@markU ACKNOWLEDGMENTS}

% Executive Summary environment - pcm01oct13
% adapted from the Abstract environment as found in
% texlive/2012/texmf-dist/tex/latex/base/report.cls
% This had to be redone because the version inherited from Mike
% failed to number the last (or only) page of the summary,
% and I couldn't figure out how to fix it.
\def\execsummaryname{\nrl@markU EXECUTIVE SUMMARY}
\newenvironment{executivesummary}{%
  \thispagestyle{plain}\cleardoublepage\thispagestyle{plain}%pcm29jul2016 changed empty to plain
  \setcounter{page}{1}
  \renewcommand*{\thepage}{E-\arabic{page}}
  \null\vspace{0.2in}	% top justify short summaries
  %\null\vfil		% vertically center short summaries
  \@beginparpenalty\@lowpenalty
  \begin{center}
    {\large \bfseries \execsummaryname}
    \@endparpenalty\@M
\end{center}
\phantomsection\addcontentsline{toc}{chapter}{\execsummaryname}%pcm29jul2016 added phantomsection
\setlength{\parindent}{1.5em}	% indentation of other paragraphs
\hspace{0.53\parindent}		% indentation of first paragraph
}%
{\par\vfil\null\cleardoublepage} % close the environment, and number last page of summary

% Here the standard latex figure and table environments are modified.
\renewenvironment{figure}%
                 {%\let\@makecaption\latex@makefigcaption% pcm27feb2021
                  \@float{figure}[htbp]% hard coded float placement - msk16sep2020
                  \centering}% replace center environment which added extra vertical space - pcm17jun19
                 {\end@float}%

\renewenvironment{figure*}%
                 {\let\@makecaption\latex@makefigcaption% pcm27feb2021
                  \@dblfloat{figure}[!htbp]% hard coded float placement - pcm24jun14
                  \centering}% replace center environment which added extra vertical space - pcm17jun19
                 {\end@dblfloat}%

\newcounter{tblmrkctr}% a counter for table superscripts - pcm24jan14
\newcounter{tblnotctr}% a counter for appended table notes - pcm24jan14

\renewenvironment{table}% - pcm17jun19
                 {\let\@makecaption\latex@maketblcaption% pcm27feb2021
                  \setcounter{tblmrkctr}{0}% initialize table note counter
                  \let\nrl@resetTPTwidth\TPT@latextablewidth% tell three-part table what width to use
                  \@float{table}[htbp]% hard coded float placement - pcm24jun14
                  \centering% replace center environment which added extra vertical space - pcm17jun19
                  \begin{threeparttable}}
                 {\end{threeparttable}\end@float}%

\renewenvironment{table*}% - pcm17jun19
                 {\let\@makecaption\latex@maketblcaption% pcm27feb2021
                  \setcounter{tblmrkctr}{0}% initialize table note counter
                  \let\nrl@resetTPTwidth\TPT@latextablewidth% tell three-part table what width to use
                  \@dblfloat{table}[!htbp]% hard coded float placement - pcm24jun14
                  \centering% replace center environment which added extra vertical space - pcm17jun19
                  \begin{threeparttable}}
                 {\end{threeparttable}\end@dblfloat}%

% font specification for the classification mark %pcm10aug16
% The rule adds a little vertical space above and below, and keeps it from crashing on empty figmarks.
%\def\nrl@figmark@insert{{\fontsize{10pt}{10pt}\bfseries\selectfont\rule[-0.2\baselineskip]{0pt}{1.2\baselineskip}{\nrl@figmark}\\}}% serif
\def\nrl@figmark@insert{{\fontsize{10pt}{10pt}\sf\bfseries\selectfont\rule[-0.2\baselineskip]{0pt}{1.2\baselineskip}{\nrl@figmark}\\}}% sans serif %pcm18feb2021

\newlength{\nrl@capwidth@min}% minimum width of a figure or table
\newlength{\nrl@boxwidth}% actual width of a figure or table
\newlength{\nrl@figmarkwidth}% width of the classification marking

\newsavebox{\nrl@box}% a box in which to construct either a figure or table %pcm10aug16

% compute the width of captions used with the new nrlfigure and nrltable environments
\def\nrl@setcapwidth%pcm22aug16
{%
  \settowidth{\nrl@boxwidth}{\usebox{\nrl@box}}% actual figure or table width
  \settowidth{\nrl@figmarkwidth}{\nrl@figmark}% width of classification marking
  \ifdim\nrl@boxwidth<\nrl@figmarkwidth%
    \setlength{\nrl@boxwidth}{\nrl@figmarkwidth}% figure or table is narrower than the marking
  \fi%
  \setlength{\nrl@capwidth@min}{0.7\textwidth}%
  \ifdim\nrl@boxwidth<\nrl@capwidth@min%
    \setlength{\nrl@capwidth}{\nrl@capwidth@min}% figure or table is narrower than the minimum caption width
  \else% full-width figure
    \ifdoing@figure%
      \ifx\nrl@figmark\@empty%
        \setlength{\nrl@capwidth}{\nrl@boxwidth}% caption spanning unboxed figure width
      \else%
        % fbox adds extra space around a boxed figure that needs to be accounted for
        \setlength{\nrl@capwidth}{\nrl@boxwidth+2\fboxrule+2\fboxsep}% caption spanning boxed figure width
      \fi%
    \else% doing table
      \setlength{\nrl@capwidth}{\nrl@boxwidth}% caption spanning unboxed table width
    \fi%
  \fi%
}%

\newenvironment{nrlfigure}[3]%pcm27feb2021
{%
  \doing@figuretrue% doing a figure
  \def\nrl@figmark{#1}% save classification marking for use in the second part
  \def\nrl@shortcaption{#2}% save short caption for TOC use
  % fig@capsize needs to be included here to accurately measure
  % line breaks for centering decision. %pcm27feb2021
  \def\nrl@caption@justified{\fig@capsize#3}% save caption for use in the second part
  \def\nrl@caption@centering{\fig@capsize\centering#3}% don't know why centering only works here
  \settowidth{\nrl@caplength}{\nrl@caption@justified}% length of the caption
  \ifx\nrl@shortcaption\@empty% make short caption for TOC
    \def\nrl@shortcaption{#3}% default for empty short caption argument
  \fi%
  \begin{lrbox}{\nrl@box}%
    \begin{varwidth}{\textwidth}%
}%
% user puts figure into a box here
{%
    \end{varwidth}%
  \end{lrbox}%
  \nrl@setcapwidth%
  \let\@makecaption\nrl@makefigcaption% new NRL format
  % set fbox parameters for boxed figures. %pcm27feb2021
  \setlength{\fboxsep}{3pt}% spacing between frame & text
  \setlength{\fboxrule}{0.5pt}% thickness of line
  \@float{figure}[htbp]% hard coded float placement - msk16sep2020
    \centering% replace center environment which added extra vertical space - pcm17jun19
    \begin{minipage}{\nrl@capwidth}%
      \ifx\nrl@figmark\@empty% print figure without a marking
          {\centering\usebox\nrl@box\\}%
      \else% print with marking
        {\centering\fbox{%
          \begin{minipage}{\nrl@boxwidth}%
            {\raggedright\nrl@figmark@insert}% TOP MARK
            {\usebox{\nrl@box}\\}% FIGURE
                   {\raggedleft\nrl@figmark@insert}% BOTTOM MARK
          \end{minipage}%
        }\\}%
      \fi%
      \ifx\nrl@figcaption\@empty%
      \else
        \hyphenpenalty10000\exhyphenpenalty10000% suppress hyphens
        \ifdim\nrl@caplength<2\nrl@capwidth% can't fix occasional widows & orphans %pcm27feb2021
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@centering}}% centered caption - pcm17jun19
        \else
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@justified}}% justified caption - pcm17jun19
        \fi%
      \fi%
    \end{minipage}%
  \end@float%
}%

\newenvironment{nrlfigure*}[3]%pcm27feb2021
{%
  \doing@figuretrue% doing a figure
  \def\nrl@figmark{#1}% save classification marking for use in the second part
  \def\nrl@shortcaption{#2}% save short caption for TOC use
  % fig@capsize needs to be included here to accurately measure
  % line breaks for centering decision. %pcm27feb2021
  \def\nrl@caption@justified{\fig@capsize#3}% save caption for use in the second part
  \def\nrl@caption@centering{\fig@capsize\centering#3}% don't know why centering only works here
  \settowidth{\nrl@caplength}{\nrl@caption@justified}% length of the caption
  \ifx\nrl@shortcaption\@empty% make short caption for TOC
    \def\nrl@shortcaption{#3}% default for empty short caption argument
  \fi%
  \begin{lrbox}{\nrl@box}%
    \begin{varwidth}{\textwidth}%
}%
% user puts figure into a box here
{%
    \end{varwidth}%
  \end{lrbox}%
  \nrl@setcapwidth%
  \let\@makecaption\nrl@makefigcaption% new NRL format
  % set fbox parameters for boxed figures. %pcm27feb2021
  \setlength{\fboxsep}{3pt}% spacing between frame & text
  \setlength{\fboxrule}{0.5pt}% thickness of line
  \@dblfloat{figure}[!htbp]% hard coded float placement - msk16sep2020
    \centering% replace center environment which added extra vertical space - pcm17jun19
    \begin{minipage}{\nrl@capwidth}%
      \ifx\nrl@figmark\@empty% print figure without a marking
          {\centering\usebox\nrl@box\\}%
      \else% print with marking
        {\centering\fbox{%
          \begin{minipage}{\nrl@boxwidth}%
            {\raggedright\nrl@figmark@insert}% TOP MARK
            {\usebox{\nrl@box}\\}% FIGURE
                   {\raggedleft\nrl@figmark@insert}% BOTTOM MARK
          \end{minipage}%
        }\\}%
      \fi%
      \ifx\nrl@figcaption\@empty%
      \else
        \hyphenpenalty10000\exhyphenpenalty10000% suppress hyphens
        \ifdim\nrl@caplength<2\nrl@capwidth% can't fix occasional widows & orphans %pcm27feb2021
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@centering}}% centered caption - pcm17jun19
        \else
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@justified}}% justified caption - pcm17jun19
        \fi%
      \fi%
    \end{minipage}%
  \end@dblfloat%
}%


% dps17feb2023
% nrlfigurew: A variant of nrlfigure which is compatible with the various packages that provide subfigures
% Tested packages include subfigure, subfig, and subcaption.  None of these will work with nrlfigure because of
% how it attempts to measure the width of the figure contents before actually typesetting them.  As a workaround here,
% the figure width must be provided as the first argument.  I'm also using the \NewEnviron command from environ.sty so
% that I can place \BODY inside an \fbox.
%\newenvironment{nrlfigurew}[4]
\NewEnviron{nrlfigurew}[4]
{%
  \doing@figuretrue% doing a figure
  \def\nrl@figmark{#2}% save classification marking for use in the second part
  \def\nrl@shortcaption{#3}% save short caption for TOC use
  % fig@capsize needs to be included here to accurately measure
  % line breaks for centering decision. %pcm27feb2021
  \def\nrl@caption@justified{\fig@capsize#4}% save caption for use in the second part
  \def\nrl@caption@centering{\fig@capsize\centering#4}% don't know why centering only works here
  \settowidth{\nrl@caplength}{\nrl@caption@justified}% length of the caption
  \ifx\nrl@shortcaption\@empty% make short caption for TOC
     \def\nrl@shortcaption{#4}% default for empty short caption argument
  \fi%
  \begin{lrbox}{\nrl@box} % fill \nrl@box with an empty box of the correct width so we can use \nrl@setcapwidth
    \makebox[#1]{}
  \end{lrbox}
  \nrl@setcapwidth% determine caption and figure width
  \let\@makecaption\nrl@makefigcaption% new NRL format
  % set fbox parameters for boxed figures. %pcm27feb2021
  \setlength{\fboxsep}{3pt}% spacing between frame & text
  \setlength{\fboxrule}{0.5pt}% thickness of line
  \@float{figure}[htbp]% hard coded float placement - msk16sep2020
    \centering% replace center environment which added extra vertical space - pcm17jun19
    \begin{minipage}{\nrl@capwidth}%
      \ifx\nrl@figmark\@empty% print figure without a marking
        {\centering%
          \begin{minipage}{\nrl@boxwidth}% note that \textwidth is the width of the outer minipage
            {\raggedright\nrl@figmark@insert}% TOP MARK
            % }{%
            \BODY\\% Insert the user's body code here.  Unlike lrbox, this works with subfigure stuff
            {\raggedleft\nrl@figmark@insert}% BOTTOM MARK
          \end{minipage}%
        \\}%
      \else% print with marking
        {\centering\fbox{%
          \begin{minipage}{\nrl@boxwidth}% note that \textwidth is the width of the outer minipage
            {\raggedright\nrl@figmark@insert}% TOP MARK
            % }{%
            \BODY\\% Insert the user's body code here.  Unlike lrbox, this works with subfigure stuff
            {\raggedleft\nrl@figmark@insert}% BOTTOM MARK
          \end{minipage}%
        }\\}%
      \fi%
      \ifx\nrl@figcaption\@empty%
      \else
        \hyphenpenalty10000\exhyphenpenalty10000% suppress hyphens
        \ifdim\nrl@caplength<2\nrl@capwidth% can't fix occasional widows & orphans %pcm27feb2021
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@centering}}% centered caption - pcm17jun19
        \else
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@justified}}% justified caption - pcm17jun19
        \fi%
      \fi%
    \end{minipage}%
  \end@float%
}

\newenvironment{nrltable}[3]%pcm27feb2021
{%
  \doing@figurefalse% doing a table
  \setcounter{tblmrkctr}{0}% initialize table note counter
  \def\nrl@figmark{#1}% save classification marking for use in the second part
  \def\nrl@shortcaption{#2}% save short caption for TOC use
  % tbl@capsize needs to be included here to accurately measure
  % line breaks for centering decision. %pcm27feb2021
  \def\nrl@caption@justified{\tbl@capsize#3}% save caption for use in the second part
  \def\nrl@caption@centering{\tbl@capsize\centering#3}% don't know why centering only works here
  \settowidth{\nrl@caplength}{\nrl@caption@justified}% length of the caption
  \ifx\nrl@shortcaption\@empty% make short caption for TOC
    \def\nrl@shortcaption{#3}% default for empty short caption argument
  \fi%
  \let\nrl@resetTPTwidth\TPT@nrltablewidth% tell three-part table what width to use
  \begin{lrbox}{\nrl@box}%
    \begin{varwidth}{\textwidth}%
      \begin{threeparttable}%
}%
% user puts table into a box here
{%
      \end{threeparttable}%
    \end{varwidth}%
  \end{lrbox}%
  \nrl@setcapwidth%
  \tbl@itemsize%
  \let\@makecaption\nrl@maketblcaption%
  \@float{table}[htbp]% hard coded float placement
    \centering% replace center environment which added extra vertical space - pcm17jun19
    \begin{minipage}{\nrl@capwidth}%
      \ifx\nrl@caption@justified\@empty%
      \else
        \hyphenpenalty10000\exhyphenpenalty10000% suppress hyphens
        \ifdim\nrl@caplength<2\nrl@capwidth% can't fix occasional widows & orphans %pcm27feb2021
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@centering}}% centered caption - pcm17jun19
        \else
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@justified}}% justified caption - pcm17jun19
        \fi%
      \fi%

      \ifx\nrl@figmark\@empty% print table without a marking
          {\centering\usebox\nrl@box\\}%
      \else% print with marking
        {\centering%
          \begin{minipage}{\nrl@boxwidth}%
            {\raggedright\nrl@figmark@insert}% TOP MARK
            {\usebox{\nrl@box}\\}% FIGURE
                   {\raggedleft\nrl@figmark@insert}% BOTTOM MARK
          \end{minipage}\\}%
      \fi%
    \end{minipage}%
  \end@float%
}%

\newenvironment{nrltable*}[3]%pcm27feb2021
{%
  \doing@figurefalse% doing a table
  \setcounter{tblmrkctr}{0}% initialize table note counter
  \def\nrl@figmark{#1}% save classification marking for use in the second part
  \def\nrl@shortcaption{#2}% save short caption for TOC use
  % tbl@capsize needs to be included here to accurately measure
  % line breaks for centering decision. %pcm27feb2021
  \def\nrl@caption@justified{\tbl@capsize#3}% save caption for use in the second part
  \def\nrl@caption@centering{\tbl@capsize\centering#3}% don't know why centering only works here
  \settowidth{\nrl@caplength}{\nrl@caption@justified}% length of the caption
  \ifx\nrl@shortcaption\@empty% make short caption for TOC
    \def\nrl@shortcaption{#3}% default for empty short caption argument
  \fi%
  \let\nrl@resetTPTwidth\TPT@nrltablewidth% tell three-part table what width to use
  \begin{lrbox}{\nrl@box}%
    \begin{varwidth}{\textwidth}%
      \begin{threeparttable}%
}%
% user puts table into a box here
{%
      \end{threeparttable}%
    \end{varwidth}%
  \end{lrbox}%
  \nrl@setcapwidth%
  \tbl@itemsize%
  \let\@makecaption\nrl@maketblcaption%
  \@dblfloat{table}[!htbp]% hard coded float placement
    \centering% replace center environment which added extra vertical space - pcm17jun19
    \begin{minipage}{\nrl@capwidth}%
      \ifx\nrl@caption@justified\@empty%
      \else
        \hyphenpenalty10000\exhyphenpenalty10000% suppress hyphens
        \ifdim\nrl@caplength<2\nrl@capwidth% can't fix occasional widows & orphans %pcm27feb2021
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@centering}}% centered caption - pcm17jun19
        \else
          \parbox{\nrl@capwidth}{\caption[\nrl@shortcaption]{\nrl@caption@justified}}% justified caption - pcm17jun19
        \fi%
      \fi%

      \ifx\nrl@figmark\@empty% print table without a marking
          {\centering\usebox\nrl@box\\}%
      \else% print with marking
        {\centering%
          \begin{minipage}{\nrl@boxwidth}%
            {\raggedright\nrl@figmark@insert}% TOP MARK
            {\usebox{\nrl@box}\\}% FIGURE
                   {\raggedleft\nrl@figmark@insert}% BOTTOM MARK
          \end{minipage}\\}%
      \fi%
    \end{minipage}%
  \end@dblfloat%
}%

% a latex table needs the width to be reset to a minimum %pcm10aug16
\def\TPT@latextablewidth
{
  \setlength{\nrl@capwidth@min}{0.7\textwidth}%
  \ifdim\wd\@tempboxb<\nrl@capwidth@min
    \hsize \nrl@capwidth@min
  \else
    \hsize\wd\@tempboxb
  \fi
}

% an nrltable always uses the actual table width %pcm10aug16
\def\TPT@nrltablewidth
{
  \hsize\wd\@tempboxb
}

% redefine threeparttable's measurement to force centering when the table is too narrow - pcm24jan14 - pcm04feb16
\def\TPT@measurement{%
  \nrl@resetTPTwidth%pcm10aug16
  \xdef\TPT@hsize{\hsize\the\hsize \noexpand\@parboxrestore}\TPT@hsize
  \ifx\TPT@docapt\@undefined\else
    \TPT@docapt \vskip.2\baselineskip
  \fi\par\begin{center}\hspace{0pt}\box\@tempboxb\end{center}% hspace{0pt} is needed for centering to work % - pcm24jan14
  \ifvmode \prevdepth\z@ \fi
}

% redefine threeparttable's tnote to make superscripts that point to the notes - pcm24jan14
% the terminating percents (%) are needed to suppress spurious blank spaces
\def\tnote#1{%
  \def\arg{#1}%
  \ifcat\arg a%
    \textsuperscript{\,\arg}
  \else
    \stepcounter{tblmrkctr}%
    \textsuperscript{\,\alph{tblmrkctr}}
  \fi
}

% set table notes font size and reset note counter - pcm24jan14
\def\TPT@defaults{\tbl@notesize\setcounter{tblmrkctr}{0}\setcounter{tblnotctr}{0}}

% make a general note function for the bottom of the table - pcm24jan14
\def\note#1{\\\hbox{\hspace{-1.2ex}\emph{Note:}~#1}}%
\def\noteN#1{\\\stepcounter{tblnotctr}\hbox{\hspace{-1.2ex}\emph{Note\,\arabic{tblnotctr}:}~#1}}%

% nrl.sty with mods to get 0.5in (36pt) spacing between figures and text
\floatsep 31pt plus 2pt minus 2pt        % Space between adjacent floats moved to top or bottom of text page
\textfloatsep 31pt plus 2pt minus 2pt    % Space between main text and floats at top or bottom of page
\intextsep 31pt plus 2pt minus 2pt       % Space between in-text here-floats and text
\dblfloatsep 12pt plus 2pt minus 2pt     % Same as \floatsep for double-column
\dbltextfloatsep 20pt plus 2pt minus 4pt % \textfloatsep for double-column
% nrl.sty with mods
\@fptop 0pt plus 1fil % Stretch at top of float page/column (must be 0pt plus ...)
\@fpsep 32pt plus 2fil % space between floats on float page/column
\@fpbot 0pt plus 1fil % Stretch at bottom of float page/column (must be 0pt plus ...)
\@dblfptop 0pt plus 1fil  % Stretch at top of float page
\@dblfpsep 8pt plus 2fil  % space between floats on float page
\@dblfpbot 0pt plus 1fil  % Stretch at bottom of float page.
% has no effect on caption generated by nrl.sty caption formatter above ?
\abovecaptionskip 14pt % 0.25in from bottom of figure to bottom of first line of caption
%\belowcaptionskip 14pt % 0.25in from bottom of last line of caption to top of table
\belowcaptionskip 2ex %pcm22jan15

% Clear some variables that were defined by LoadClass{report}.
% The problem is that the report class inputs size10.clo, which pre-defines sizes we want to redefine.
\def\nrl@loadfont@clear{%pcm20jun16
  \let\normalsize\@empty%  because size1?.clo calls renewcommand{normalsize}
  \let\small\relax%	   because size1?.clo calls   newcommand{small}
  \let\footnotesize\relax% ditto
  \let\scriptsize\relax
  \let\tiny\relax
  \let\large\relax
  \let\Large\relax
  \let\LARGE\relax
  \let\huge\relax
  \let\Huge\relax
}

% define how to load the various font sizes
\def\nrl@loadfont@sizeXpt{\nrl@loadfont@clear\input{size10.clo}}%pcm20jun16
\def\nrl@loadfont@sizeXIIpt{\nrl@loadfont@clear\input{size12.clo}}%pcm20jun16

\def\nrl@loadfont@sizeXIpt{%pcm20jun16
  \nrl@loadfont@clear\input{size11.clo}
  \renewcommand\normalsize{%
    \@setfontsize\normalsize\@xipt{13.6}%
    \abovedisplayskip 17\p@ \@plus4\p@ \@minus4\p@ % affects the space above most equations
    \belowdisplayskip 17\p@ \@plus4\p@ \@minus4\p@
    \abovedisplayshortskip 5\p@ \@plus4\p@ % affects equations not affected by abovedisplayskip
    \belowdisplayshortskip 17\p@ \@plus4\p@ \@minus4\p@
    \let\@listi\@listI}
  \renewcommand\small{%
    \@setfontsize\small\@xpt\@xiipt
    \abovedisplayskip 15\p@ \@plus3\p@ \@minus3\p@
    \belowdisplayskip 15\p@ \@plus3\p@ \@minus3\p@
    \abovedisplayshortskip 4\p@ \@plus3\p@
    \belowdisplayshortskip 15\p@ \@plus3\p@ \@minus3\p@
    \def\@listi{\leftmargin\leftmargini
      \topsep 6\p@ \@plus2\p@ \@minus2\p@
      \parsep 3\p@ \@plus2\p@ \@minus\p@
      \itemsep \parsep}}
  \renewcommand\footnotesize{%
    \@setfontsize\footnotesize\@ixpt{11}%
    \abovedisplayskip 13\p@ \@plus2\p@ \@minus2\p@
    \belowdisplayskip 13\p@ \@plus2\p@ \@minus2\p@
    \abovedisplayshortskip 3\p@ \@plus2\p@
    \belowdisplayshortskip 13\p@ \@plus2\p@ \@minus2\p@
    \def\@listi{\leftmargin\leftmargini
      \topsep 4\p@ \@plus2\p@ \@minus2\p@
      \parsep 2\p@ \@plus\p@ \@minus\p@
      \itemsep \parsep}}
}

% Now finally, load the chosen font
\nrl@loadfont%pcm20jun16

% (line 4238) latex.ltx
%\def\equation{$$\refstepcounter{equation}}
%\def\endequation{\eqno \hbox{\@eqnnum}$$\@ignoretrue}
%\def\@eqnnum{{\normalfont \normalcolor (\theequation)}}

\newlength{\footheight}
\def\setReportMargins{
  \setlength{\paperwidth}{8.5in}
  \setlength{\paperheight}{11in}

  \setlength{\textwidth}{6.5in}
  \setlength{\textheight}{8.7in}

  \setlength{\hoffset}{0.00in}% sets the left margin position

  \setlength{\oddsidemargin}{0.00in}
  \setlength{\evensidemargin}{0.00in}

  \setlength{\marginparsep}{0pt}
  \setlength{\marginparwidth}{0pt}
  \setlength{\marginparpush}{0pt}

  \setlength{\voffset}{0.00in}% sets the head position
  \setlength{\topmargin}{-0.25in}
  \setlength{\headheight}{0.15in}
  \setlength{\footheight}{0.10in}
  \setlength{\headsep}{0.40in}

  % footskip sets the vertical position of the page number
  % it is measured downwards from somewhere
  \setlength{\footskip}{0.50in}
  \setlength{\footnotesep}{5.0pt}

  \setlength{\parindent}{1.5em}

  \parskip	12.6pt plus 1ex minus 1ex %pcm24oct13 need 1ex of discretionary vertical space to avoid widows & orphans

  \setlength{\fboxsep}{3pt}	% hyperref default values that are
  \setlength{\fboxrule}{0.4pt}	% temporarily changed in the NRLabstract

  % other parameters
  %\lineskip 1pt
  %\normallineskip 1pt
  %\parindent 2em                    % Width of paragraph indentation.
  %\topsep 10pt plus 4pt minus 6pt   % Extra vertical space, in addition to
  %                                  % \parskip, added above and below list and
  %                                  % paragraphing environments.
  %\partopsep 3pt plus 2pt minus 1pt % Extra vertical space, in addition to
  %                                  % \parskip and \topsep, added when user
  %                                  % leaves blank line before environment.
  %\itemsep 5pt plus 2.5pt minus 1pt % Extra vertical space, in addition to
  % \parskip, added between list items.
  % See \@listI for values of \topsep and \itemsep
}
\setReportMargins

% avoid widows & orphans
\clubpenalty 10000     %%% 'Club line'  at bottom of page.
\widowpenalty 10000    %%% 'Widow line' at top of page.
\brokenpenalty 10000   %%% Breaking after a hyphenated line.

% \displaywidowpenalty % Math display widow line.
% \predisplaypenalty   % Breaking before a math display.
% \postdisplaypenalty  % Breaking after a math display.
% \interlinepenalty    % Breaking at a line within a paragraph.

\flushbottom % \raggedbottom may move approval date footnote on first page

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NRL report bibliography and citation formats - pcm13apr12

% It is simplest to use \cite everywhere in your paper,
% using \citep and \citet for special effects where needed.

% The NRL bibliography formats are based on the natbib package by
%   Patrick W. Daly, "Natural Sciences Citations and References."
% For appendix references, the bibunits package by Thorsten Hansen is used.

% natbib citation styles - choose one
% preferred NRL bibliography style (default)
% pcm15sep2021 preferred style is now set above in \RequirePackage[numbers,sort&compress]{natbib}
% if necessary, override the default here
%\setcitestyle{numbers,comma,open={\,[},close={]}}	% bracketed numerical citations, numbered references
%\setcitestyle{super,comma,open={},close={}}		% superscript citations, numbered references
%\setcitestyle{round,authoryear,semicolon}		% author-year citations, unnumbered references

% bibliography styles - choose one
% make bibunits style the same as the main bibliography
%
% bibliography in citation order using initials, last name
% preferred NRL bibliography style (default)
\bibliographystyle{nrlunsrtabbrvnat}		% natbib
\defaultbibliographystyle{nrlunsrtabbrvnat}	% bibunits
%
% bibliography in citation order using full names
%\bibliographystyle{nrlunsrtnat} 		% natbib
%\defaultbibliographystyle{nrlunsrtnat}		% bibunits
%
% bibliography in alphabetic order using initials, last name
%\bibliographystyle{nrlabbrvnat} 		% natbib
%\defaultbibliographystyle{nrlabbrvnat}		% bibunits
%
% bibliography in alphabetic order using full names
%\bibliographystyle{nrlplainnat} 		% natbib
%\defaultbibliographystyle{nrlplainnat}		% bibunits

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Use these macros. - pcm13apr12
% They simplify insertion of cross-references, and ensure uniformity of style.
% If the style specification changes, fix it here.
% These macros may be overridden in your paper preamble using "renewcommand".
% TIS wants all chapters and sections to be labeled "section" without abbreviation
\newcommand{\Eqn}[1]{Equation~(\ref{#1})}
\newcommand{\Fig}[1]{Figure~\ref{#1}}
\newcommand{\Tbl}[1]{Table~\ref{#1}}
\newcommand{\Chap}[1]{Section~\ref{#1}}
\newcommand{\Secn}[1]{Section~\ref{#1}}
\newcommand{\App}[1]{Appendix~\ref{#1}}

\newcommand{\Eqns}[2]{Equations~(\ref{#1})\,--\,(\ref{#2})}
\newcommand{\Figs}[2]{Figures~\ref{#1}\,--\,\ref{#2}}
\newcommand{\Tbls}[2]{Tables~\ref{#1}\,--\,\ref{#2}}
\newcommand{\Secs}[2]{Sections~\ref{#1}\,--\,\ref{#2}}

\newcommand{\Eqnand}[2]{Equations~(\ref{#1}) and (\ref{#2})}
\newcommand{\Figand}[2]{Figures~\ref{#1} and \ref{#2}}
\newcommand{\Tbland}[2]{Tables~\ref{#1} and \ref{#2}}
\newcommand{\Secand}[2]{Sections~\ref{#1} and \ref{#2}}

\newcommand{\eqn}[1]{Eq.\,(\ref{#1})}
\newcommand{\fig}[1]{Fig.\,\ref{#1}}
\newcommand{\tbl}[1]{Table~\ref{#1}}
\newcommand{\chap}[1]{Section~\ref{#1}}
\newcommand{\secn}[1]{Section~\ref{#1}}
\newcommand{\app}[1]{Appendix~\ref{#1}}

\newcommand{\eqns}[2]{Eqs.\,(\ref{#1})\,--\,(\ref{#2})}
\newcommand{\figs}[2]{Figs.\,\ref{#1}\,--\,\ref{#2}}
\newcommand{\tbls}[2]{Tables~\ref{#1}\,--\,\ref{#2}}
\newcommand{\secs}[2]{Sections~\ref{#1}\,--\,\ref{#2}}

\newcommand{\eqnand}[2]{Eqs.\,(\ref{#1}) and (\ref{#2})}
\newcommand{\figand}[2]{Figs.\,\ref{#1} and \ref{#2}}
\newcommand{\tbland}[2]{Tables~\ref{#1} and \ref{#2}}
\newcommand{\secand}[2]{Sections~\ref{#1} and \ref{#2}}

% produces e.g. "Ref. [99]" in your text
% Forcibly provide a \Ref command, whether or not it is predefined.
% texlive-2020 predefines this command, whereas older versions do not.
\def\Ref#1{Ref.\,\citenum{#1}}

% insert physical units using math mode set in roman font
\newcommand{\units}[1]{\ensuremath{\mathrm{~#1}}}
\newcommand{\hunits}[1]{\ensuremath{\mathrm{\text{-}{#1}}}}

\DeclareMathOperator{\tr}{\mathrm{tr}}
\providecommand{\LyX}{L\kern-.1667em\lower.25em\hbox{Y}\kern-.125emX\@}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%pcm6jul12
% hyperref breaks if specified at top of file
% activate pdf hyper-links to sections, equations, and citations

\RequirePackage[colorlinks=true,linkcolor=black,citecolor=black,urlcolor=black,unicode=true,bookmarksdepth=3]{hyperref}
\RequirePackage{doi}		% enables hot-link doi in the references - must follow hyperref
\RequirePackage{zref-totpages}	% enables total page count - docs say it must be last package

% these must follow hyperref
% ease the insertion of security marks - pcm26jun17
\renewcommand{\u}{{(U)}~}
\newcommand{\f}{{(FOUO)}~}
\newcommand{\uf}{{(U//FOUO)}~}
\newcommand{\cui}{(CUI)~}
\newcommand{\cuinf}{(CUI//NF)~}
\newcommand{\cuirel}{(CUI//REL TO)~}
\renewcommand{\c}{{(C)}~}
\newcommand{\s}{{(S)}~}
\newcommand{\sn}{{(S//NF)}~}

% stuff below to portion-mark equations on the left using \Ueq, \CUIeq etc, inside equations
% https://tex.stackexchange.com/questions/472728/marginnote-always-on-left-side-of-the-page
\usepackage{marginnote}
\patchcmd{\@mn@@@marginnote}{\begingroup}{\begingroup\@twosidefalse}{}{\fail}
\reversemarginpar
\newcommand{\Ueq}[1][-1.1em]{\marginnote{(U)}[#1]} % need an offset upwards to align with equation, default is 1.1em
\newcommand{\Ceq}[1][-1.1em]{\marginnote{(C)}[#1]} 
\newcommand{\Seq}[1][-1.1em]{\marginnote{(S)}[#1]} 
\newcommand{\CUIeq}[1][-1.1em]{\marginnote{(CUI)}[#1]}

% from url.sty: also break urls at hyphens
\def\UrlBreaks{\do\.\do\@\do\\\do\/\do\!\do\_\do\|\do\;\do\>\do\]%
 \do\)\do\,\do\?\do\'\do+\do\=\do\#\do-}%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The remaining stuff below here makes the SF-298 REPORT DOCUMENTATION PAGE.

% macros/variables for user to adjust spacing of Field 7 and 14 in the case of many organizations
\newlength{\D@orgabs}\setlength{\D@orgabs}{0in}
\def\nrlorgstretchabs#1{\setlength{\D@orgabs}{#1}}

% Set margins of the documentation page.
% Lengths that are commented out are the same as those in setReportMargins.
\def\setAbstractMargins{% pcm15sep2021

  %\setlength{\paperwidth}{8.5in}
  %\setlength{\paperheight}{11in}

  \setlength{\textwidth}{8.0in}% horizontal size of main box

  % Do not change the textheight!
  % It does not reset properly, causing following page numbers to disapear.
  %\setlength{\textheight}{8.7in}

  \setlength{\hoffset}{-0.75in}% sets the left margin position

  %\setlength{\oddsidemargin}{0.00in}
  %\setlength{\evensidemargin}{0.00in}

  %\setlength{\marginparsep}{0pt}
  %\setlength{\marginparwidth}{0pt}
  %\setlength{\marginparpush}{0pt}

  \setlength{\voffset}{-0.375in}% sets the head position
  \setlength{\topmargin}{0in}
  \setlength{\headheight}{0in}
  \setlength{\footheight}{0in}
  \setlength{\headsep}{3pt}% space between mark & box

  % footskip sets the vertical position of the page number
  % it is measured downward from somewhere
  \setlength{\footskip}{1.35in}
  \setlength{\footnotesep}{0pt}

  \setlength{\parindent}{0em}
  \setlength{\fboxsep}{0pt}
}

\def\setAbstractLengths{% pcm15sep2021

  %% define a negative thin space that aligns vertically consecutive box edges.
  \newlength{\D@nv}\setlength{\D@nv}{-1pt}

  %% master control for vertical shifts of text content
  % positive vertical space between top of a box and the label below
  \newlength{\D@dy}\setlength{\D@dy}{3pt}

  %% master control for horizontal shifts of text content
  % positive horizontal space between the left edge of a box and the label/text to the right
  \newlength{\D@dx}\setlength{\D@dx}{4pt}

  %% make short-name functions that do the various alignments
  \def\A@nv{\vspace*{\D@nv}}
  \def\A@dx{\hspace*{\D@dx}}
  \def\A@nx{\hspace*{-\D@dx}}
  \def\A@dy{\vspace*{\D@dy}}

  %% \textwidth is the master control for box & text widths.
  % define the widths of framed boxes.
  \newlength{\B@a}\setlength{\B@a}{0.19\textwidth}% box 18
  \newlength{\B@b}\setlength{\B@b}{0.2\textwidth}% boxes 1, 3 (start and end)
  \newlength{\B@c}\setlength{\B@c}{0.24\textwidth}% box 17
  \newlength{\B@d}\setlength{\B@d}{0.3\textwidth}%
  \newlength{\B@e}\setlength{\B@e}{0.33333\textwidth}%
  \newlength{\B@f}\setlength{\B@f}{0.4\textwidth}%
  \newlength{\B@g}\setlength{\B@g}{0.57\textwidth}% box 9 and 16
  \newlength{\B@h}\setlength{\B@h}{0.7\textwidth}%
  \newlength{\B@i}\setlength{\B@i}{\textwidth}%
  \newlength{\B@j}\setlength{\B@j}{0.19\textwidth}% boxes 16a, 16b, 16c, should be 1/3 of \B@g (Box 16)
  \newlength{\B@k}\setlength{\B@k}{0.215\textwidth}% boxes 10 and 11

  % define the widths of text content.
  % box contents are narrower than their containing box.
  \newlength{\C@a}\setlength{\C@a}{\B@a}\addtolength{\C@a}{-2\D@dx}
  \newlength{\C@b}\setlength{\C@b}{\B@b}\addtolength{\C@b}{-2\D@dx}
  \newlength{\C@c}\setlength{\C@c}{\B@c}\addtolength{\C@c}{-2\D@dx}
  \newlength{\C@d}\setlength{\C@d}{\B@d}\addtolength{\C@d}{-2\D@dx}
  \newlength{\C@e}\setlength{\C@e}{\B@e}\addtolength{\C@e}{-2\D@dx}
  \newlength{\C@f}\setlength{\C@f}{\B@f}\addtolength{\C@f}{-2\D@dx}
  \newlength{\C@g}\setlength{\C@g}{\B@g}\addtolength{\C@g}{-2\D@dx}
  \newlength{\C@h}\setlength{\C@h}{\B@h}\addtolength{\C@h}{-2\D@dx}
  \newlength{\C@i}\setlength{\C@i}{\B@i}\addtolength{\C@i}{-2\D@dx}
  \newlength{\C@j}\setlength{\C@j}{\B@j}\addtolength{\C@j}{-2\D@dx}
  \newlength{\C@k}\setlength{\C@k}{\B@k}\addtolength{\C@k}{-2\D@dx}

  % heights of the five large text boxes
  % reapportion if needed; must total 4.31in
  \newlength{\H@org}	\setlength{\H@org}{0.8in}\addtolength{\H@org}{\D@orgabs}
  \newlength{\H@dist}	\setlength{\H@dist}{0.65in}
  \newlength{\H@supp}	\setlength{\H@supp}{0.65in}
  \newlength{\H@abst}	\setlength{\H@abst}{1.56in}\addtolength{\H@abst}{-\D@orgabs}
  \newlength{\H@subj}	\setlength{\H@subj}{0.65in}

  % the height of these two interior boxes depends on the vertical separation of text below the containing box top.
  \newlength{\H@date}\setlength{\H@date}{0.355in}\addtolength{\H@date}{-\D@dy}
  \newlength{\H@class}\setlength{\H@class}{0.505in}\addtolength{\H@class}{-\D@dy}
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SF-298 REPORT DOCUMENTATION PAGE
% This needs to be a TeX macro. Use of a LaTeX environment causes loss of control over the margins.
% The general idea is to put a paragraph inside a frame:
% \framebox[width][left]{\parbox[top][height][top]{width}{some text}}
%
\def\nrlabstract#1{% entirely new documentation page format %pcm15sep2021
  \setcounter{page}{1}
  \thispagestyle{plain}
  \setAbstractMargins%
  \setAbstractLengths%
  \setlength{\fboxrule}{3pt}% thick frame around main box
  \framebox{% main framebox
  \begin{minipage}[b][9.5in][t]{\textwidth}% encapsulate the entire documentation page
    \footnotesize\sffamily\bfseries% default font for the form titles
    \setlength{\fboxrule}{0.4pt}% thin frame around interior boxes
    %
    \framebox[\textwidth]{\parbox[t][0.5in][c]{\textwidth}{\centering%
        {\Large{REPORT DOCUMENTATION PAGE}}}}\A@nv\\%
    %
    \framebox[\textwidth]{\parbox[t][0.25in][c]{\textwidth}{\A@dx%
        {PLEASE DO NOT RETURN YOUR FORM TO THE ABOVE ORGANIZATION}%
    }}\A@nv\\%
    %
    \framebox[\textwidth]{\parbox[t][0.5in][t]{\textwidth}{%
        \framebox[\B@b][l]{\A@dx\parbox[t][0.5in][t]{\C@b}{\A@dy{1.\ REPORT DATE\\\nrl@reportdate}}}%
        \framebox[\B@f][l]{\A@dx\parbox[t][0.5in][t]{\C@f}{\A@dy{2.\ REPORT TYPE\\\nrl@reporttype}}}%
        \framebox[\B@f][l]{\A@dx\parbox[t][0.5in][t]{\C@f}{\A@dy{3.\ DATES COVERED\vspace*{-1.5ex}}\\%
            \A@nx\framebox[\B@b][l]{\A@dx\parbox[t][\H@date][t]{\C@b}{\A@dy{START DATE\\\nrl@startdate}}}%
            \framebox[\B@b][l]{\A@dx\parbox[t][\H@date][t]{\C@b}{\A@dy{END DATE\\\nrl@enddate}}}%
        }}%
    }}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][0.5in][t]{\textwidth}{\A@dy\A@dx%
        \parbox{\C@i}{4.\ TITLE AND SUBTITLE\\\raggedright\mdseries\@title}}}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][0.5in][t]{\textwidth}{%
        \framebox[\B@e][l]{\A@dx\parbox[t][0.5in][t]{\C@e}{\A@dy{5a.\ CONTRACT NUMBER\\\nrl@contractnumber}}}%
        \framebox[\B@e][l]{\A@dx\parbox[t][0.5in][t]{\C@e}{\A@dy{5b.\ GRANT NUMBER\\\nrl@grantnumber}}}%
        \framebox[\B@e][l]{\A@dx\parbox[t][0.5in][t]{\C@e} {\A@dy{5c.\ PROGRAM ELEMENT NUMBER\\\nrl@programelement}%
        }}%
    }}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][0.5in][t]{\textwidth}{%
        \framebox[\B@e][l]{\A@dx\parbox[t][0.5in][t]{\C@e}{\A@dy{5d.\ PROJECT NUMBER\\\nrl@projectnumber}}}%
        \framebox[\B@e][l]{\A@dx\parbox[t][0.5in][t]{\C@e}{\A@dy{5e.\ TASK NUMBER\\\nrl@tasknumber}}}%
        \framebox[\B@e][l]{\A@dx\parbox[t][0.5in][t]{\C@e}{\A@dy{5f.\ WORK UNIT NUMBER\\\nrl@workunitnumber}%
        }}%
    }}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][0.5in][t]{\textwidth}{\A@dy\A@dx%
        \parbox{\C@i}{6.\ AUTHOR(S)\\\raggedright\mdseries\nrl@authorlist}}}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][\H@org][t]{\textwidth}{%
        \framebox[\B@h][l]{\A@dx\parbox[t][\H@org][t]{\C@h}{\A@dy{7.\ PERFORMING ORGANIZATION / AFFILIATION NAME(S) AND ADDRESS(ES)\\\nrl@organizationaddress}}}%
        \framebox[\B@d][l]{\A@dx\parbox[t][\H@org][t]{\C@d}{\A@dy{8.\ PERFORMING ORGANIZATION\\REPORT NUMBER\\\nrl@reportnumber}}}%
    }}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][0.8in][t]{\textwidth}{%
        \framebox[\B@g][l]{\A@dx\parbox[t][0.8in][t]{\C@g}{\A@dy{9.\ SPONSORING / MONITORING AGENCY NAME(S) AND ADDRESS(ES)\\\nrl@sponsoraddress}}}%
        \framebox[\B@k][l]{\A@dx\parbox[t][0.8in][t]{\C@k}{\A@dy{10.\ SPONSOR / MONITOR'S\\ACRONYM(S)\\\nrl@sponsoracronym}}}%
        \framebox[\B@k][l]{\A@dx\parbox[t][0.8in][t]{\C@k} {\A@dy{11.\ SPONSOR / MONITOR'S\\REPORT NUMBER(S)\\\nrl@sponsorreportnumber}%
        }}%
    }}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][\H@dist][t]{\textwidth}{\A@dy\A@dx%
        \parbox{\C@i}{12.\ DISTRIBUTION / AVAILABILITY STATEMENT\\\raggedright\mdseries\nrl@distribution}}}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][\H@supp][t]{\textwidth}{\A@dy\A@dx%
        \parbox{\C@i}{13.\ SUPPLEMENTAL NOTES\\\raggedright\mdseries\nrl@supplementalnotes\ifx\nrl@supplementalnotes\@empty\else\ifx\nrl@deceaseddate\@empty\else,\fi\fi\nrl@deceaseddate}}}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][\H@abst][t]{\textwidth}{\A@dy\A@dx%
        \parbox{\C@i}{14.\ ABSTRACT\\\raggedright\mdseries{#1}}}}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][\H@subj][t]{\textwidth}{\A@dy\A@dx%
        \parbox{\C@i}{15.\ SUBJECT TERMS\\\raggedright\nrl@subjectterms}}}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][0.65in][t]{\textwidth}{%
        \framebox[\B@g][l]{\A@dx\parbox[t][0.65in][t]{\C@g}{\A@dy{16.\ SECURITY CLASSIFICATION OF:}\vspace*{-1.5ex}\\%
            \A@nx\framebox[\B@j][l]{\A@dx\parbox[t][\H@class][t]{\C@j}{\A@dy{a.\ REPORT\\\nrl@reportclass}}}%
            \framebox[\B@j][l]{\A@dx\parbox[t][\H@class][t]{\C@j}{\A@dy{b.\ ABSTRACT\\\nrl@abstractclass}}}%
            \framebox[\B@j][l]{\A@dx\parbox[t][\H@class][t]{\C@j}{\A@dy{c.\ THIS PAGE\\\nrl@thispageclass}}}%
        }}%
        \framebox[\B@c][l]{\A@dx\parbox[t][0.65in][t]{\C@c}{\A@dy{17.\ LIMITATION OF ABSTRACT\\\nrl@abstractlimitation}}}%
        \framebox[\B@a][l]{\A@dx\parbox[t][0.65in][t]{\C@a}{\A@dy{18.\ NUMBER OF PAGES\\{\centering\nrl@numpages\\}}}}%
    }}\A@nv\\%
    %
    \framebox[\textwidth][l]{\parbox[t][0.35in][t]{\textwidth}{%
        \framebox[\B@h][l]{\A@dx\parbox[t][0.35in][t]{\C@h}{\A@dy{19a.\ NAME OF RESPONSIBLE PERSON \\\nrl@responsibleperson}}}%
        \framebox[\B@d][l]{\A@dx\parbox[t][0.35in][t]{\C@d}{\A@dy{19b.\ PHONE NUMBER {\it\sffamily(Include area code)}\\\nrl@telephonenumber}}}%
    }}\vspace*{3pt}\\%controls vertical position of footnotes
    %
    % footnotes
    \parbox{\textwidth}{\footnotesize\sffamily\mdseries%
      {Page 1 of 2\hspace*{2.57in}{PREVIOUS EDITION IS OBSOLETE}\hfill{STANDARD FORM 298 (REV. 5/2020)}\\}%
      {\strut\hfill\it\sffamily{Prescribed by ANSI Std. Z39.18}}}%
    %
  \end{minipage}%
  }\\% end main framebox
  %
  % see \footskip above for vertical height of page number
  \clearpage
  \setReportMargins
  \cleardoublepage
}% end nrlabstract
%%
%% End of file 'nrlreport.cls'.
