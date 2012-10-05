#!/usr/bin/env python

import sys

if len(sys.argv) < 2:
  print 'No module name given'
  sys.exit(2)

for modname in sys.argv[1:]:

  modfile = open (modname + '.v', 'w')

  modfile.write('module ' + modname + '(input clk, input rst);\n')
  modfile.write('  always @(*) begin\n\n')
  modfile.write('  end\n\n')
  modfile.write('  always @(posedge clk) begin\n\n')
  modfile.write('  end\n\n')
  modfile.write('endmodule\n')


