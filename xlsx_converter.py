#!/usr/bin/env python
"""
xlsx2tsv  filename.xlsx  [sheet number or name]

Parse a .xlsx (Excel OOXML, which is not OpenOffice) into tab-separated values.
If it has multiple sheets, need to give a sheet number or name.
Outputs honest-to-goodness tsv, no quoting or embedded \\n\\r\\t.

One reason I wrote this is because Mac Excel 2008 export to csv or tsv messes
up encodings, converting everything to something that's not utf8 (macroman
perhaps).  This script seems to do better.

The spec for this format is 5220 pages.  I did not use it.  This was helpful:
http://blogs.msdn.com/excel/archive/2008/08/14/reading-excel-files-from-linux.aspx
But mostly I guessed how the format works.  So bugs are guaranteed.

brendan o'connor - anyall.org - gist.github.com/22764
"""

#from __future__ import print_function
import xml.etree.ElementTree as ET
import os,sys,zipfile,re,itertools

def myjoin(seq, sep=" "):
  " because str.join() is annoying "
  return sep.join(str(x) for x in seq)

args = sys.argv[:]
args.pop(0)
if args:
  z = zipfile.ZipFile(args.pop(0))
elif not sys.stdin.isatty():
  z = zipfile.ZipFile(sys.stdin)
else:
  print __doc__.strip()
  sys.exit(1)

n=lambda x: "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}%s" % x

sheet_filenames = [f for f in z.namelist() if re.search("^xl/worksheets/sheet.*xml$", f)]
workbook_x = ET.XML(z.read("xl/workbook.xml"))
sheet_xs = workbook_x.find(n("sheets")).findall(n("sheet"))

def sheet_report():
  global sheet_xs
  print>>sys.stderr, "Sheets in this file:"
  for i,x in enumerate(sheet_xs):
    print>>sys.stderr, "%3d: %s" % (i+1, x.get('name'))
  sys.exit(1)

def sheet_error(msg):
  print>>sys.stderr, msg
  sheet_report()

if not args and len(sheet_filenames) > 1:
  sheet_error("There are multiple sheets -- need to specify a sheet number or name.")
elif not args and len(sheet_filenames) == 1:
  sheet_num = 1
elif args:
  sheet_num = args.pop(0)

if isinstance(sheet_num,str) and (not re.search('^[0-9]+$',sheet_num) or int(sheet_num) > len(sheet_filenames)):
  name = sheet_num
  inds = [i for i,x in enumerate(sheet_xs)  if x.get('name')==name]
  if not inds: sheet_error("Can't find sheet with name '%s'" % name)
  if len(inds)>1: sheet_error("Multiple sheets with name '%s'" % name)
  sheet_num = inds[0] + 1


def letter2col_index(letter):
  """ A -> 0, B -> 1, Z -> 25, AA -> 26, BA -> 52 """
  base26digits = [1+ord(x)-ord("A") for x in letter]
  return sum([x*26**(len(base26digits) - k - 1)  for k,x in enumerate(base26digits)]) - 1

def flatten(iter):
  return list(itertools.chain(*iter))

def cell2text(cell):
  if cell is None:
    return ""
  elif 't' in cell.attrib and cell.attrib['t'] == 's':
    # shared string
    idx = int(cell.find(n("v")).text)
    si = ss_list[idx]
    t_elt = si.find(n("t"))
    if t_elt is not None:
      return t_elt.text
    t_elts = si.findall(n("r") + "/" + n("t"))
    if t_elts:
      text = "".join( (t.text) for t in t_elts )
      return text
    raise Exception("COULDNT DECODE CELL: %s" % ET.tostring(si))
    #return si.find(n("t")).text
    #return ET.tostring(si)
  else:
    v_elt = cell.find(n("v"))
    if v_elt is None: return ""
    return v_elt.text


ss_xml = z.read("xl/sharedStrings.xml")
ss_list = ET.XML(ss_xml).findall(n("si"))

xml = z.read("xl/worksheets/sheet%s.xml" % sheet_num)
s = ET.fromstring(xml)
rows = s.findall(n("sheetData")+"/"+n("row"))

all_cells = flatten( [[c for c in row.findall(n("c"))] for row in rows] )
max_col = max(letter2col_index(re.search("^[A-Z]+",c.attrib['r']).group()) for c in all_cells)

def make_cells():
  return [None] * (max_col+1)

warning_count=0
warning_max = 50
def warning(s):
  global warning_count
  warning_count += 1
  if warning_count > warning_max: return
  print>>sys.stderr, "WARNING: %s" % s

def cell_text_clean(text):
  s = text.encode("utf-8")
  if "\t" in s: warning("Clobbering embedded tab")
  if "\n" in s: warning("Clobbering embedded newline")
  if "\r" in s: warning("Clobbering embedded carriage return")
  s = s.replace("\t"," ").replace("\n"," ").replace("\r"," ")
  return s

for row in rows:
  cells_elts = row.findall(n("c"))
  inds = []  # parallel
  for c in cells_elts:
    letter = re.search("^[A-Z]+", c.attrib['r']).group()
    inds.append(letter2col_index(letter) )
  cells = make_cells()
  for c,j in zip(cells_elts,inds):
    cells[j] = c
  #print( *(cell2text( c ).encode("utf-8").replace("\t"," ") for c in cells), sep="\t")
  print myjoin((cell_text_clean(cell2text( c )) for c in cells), sep="\t")

if warning_count > warning_max:
  print>>sys.stderr, "%d total warnings, %d hidden" % (warning_count, warning_count-warning_max)
