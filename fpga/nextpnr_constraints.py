# The installed gowin_pack release cannot pack the left-side PLL on GW1N-9C.
# Use the equivalent right-side PLL, which also avoids unnecessary ambiguity.
pll_bel = next(bel for bel in ctx.getBels() if str(bel) == "X46Y9/PLL")
ctx.bindBel(pll_bel, ctx.cells["taro_inst.hdmi_inst.pll_inst"], STRENGTH_USER)
