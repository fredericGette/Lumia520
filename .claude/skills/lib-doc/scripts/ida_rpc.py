# Run with mcp__ida__execute_python (paste the file content as `code`).
# Lists the RPC client procedures of the open binary: for every caller of NdrClientCall2 (or
# NdrClientCall4 / NdrClientCall3), the MIDL stub descriptor, the interface GUID and version, the opnum,
# the stack size and the parameter descriptors of the -Oif proc format string.
# Works for the ARM (Thumb-2) binaries of the phone: the stub descriptor is loaded in R0 and the
# proc format string in R1 before the call.
import struct, uuid
import idautils, idc, ida_bytes, ida_funcs, ida_ua


def _dw(ea):
    return ida_bytes.get_dword(ea)


def _guid(ea):
    return "{%s}" % str(uuid.UUID(bytes_le=ida_bytes.get_bytes(ea, 16))).upper()


def _reg_value(call_ea, reg):
    """Value loaded in register `reg` (0 = R0, 1 = R1) before `call_ea`, following
    LDR Rd, =x / ADR Rd, x / ADD Rd, Rs, #imm / ADD Rd, #imm / MOV Rd, Rs backwards."""
    f = ida_funcs.get_func(call_ea)
    ea, add = call_ea, 0
    for _ in range(16):
        ea = idc.prev_head(ea, f.start_ea if f else 0)
        if ea == idc.BADADDR:
            break
        insn = ida_ua.insn_t()
        if not ida_ua.decode_insn(insn, ea) or insn.Op1.type != idc.o_reg or insn.Op1.reg != reg:
            continue
        m = idc.print_insn_mnem(ea).upper()
        if m.startswith("ADD") and insn.Op2.type == idc.o_reg and insn.Op3.type == idc.o_imm:
            add += insn.Op3.value          # ADD Rd, Rs, #imm: continue with Rs
            reg = insn.Op2.reg
            continue
        if m.startswith("ADD") and insn.Op2.type == idc.o_imm:
            add += insn.Op2.value
            continue
        if m.startswith("MOV") and insn.Op2.type == idc.o_reg:
            reg = insn.Op2.reg
            continue
        if m.startswith(("LDR", "ADR", "MOV")) and insn.Op2.type in (idc.o_mem, idc.o_imm):
            v = idc.get_operand_value(ea, 1)
            if m.startswith("LDR") and insn.Op2.type == idc.o_mem:
                v = _dw(v)                 # LDR Rd, =x : literal pool
            return v + add
        return None                        # loaded from the stack or computed: give up
    return None


def _proc(fmt):
    b = ida_bytes.get_bytes(fmt, 24)
    flags = b[1]
    off = 2 + (4 if flags & 0x08 else 0)            # Oi_HAS_RPCFLAGS
    opnum, stack = struct.unpack_from("<HH", b, off)
    off += 4
    if b[0] == 0:                                    # explicit handle: 4-byte (FC_BIND_PRIMITIVE) or more
        off += 4 if b[off] == 0x32 else 6
    client, server, oi2, nparams = struct.unpack_from("<HHBB", b, off)
    off += 6
    if oi2 & 0x40:                                   # has extensions
        off += ida_bytes.get_byte(fmt + off)
    params = []
    for i in range(nparams):
        attr, so, t = struct.unpack("<HHH", ida_bytes.get_bytes(fmt + off + 6 * i, 6))
        d = []                                       # PARAM_ATTRIBUTES (ndr64types.h)
        if attr & 0x0020: d.append("return")
        else:
            if attr & 0x0008: d.append("in")
            if attr & 0x0010: d.append("out")
        if attr & 0x0040: d.append("base 0x%02X" % (t & 0xFF))   # FC_LONG = 0x08, FC_HYPER = 0x0B, …
        else: d.append("type@%d" % t)                # offset in the type format string
        if attr & 0x0100: d.append("simple ref")
        if attr & 0x0080: d.append("by value")
        params.append("stack %d [%s] attr %04X" % (so, ", ".join(d), attr))
    return opnum, stack, params


def run(db):
    targets = [ea for ea, name in ((ea, idc.get_name(ea)) for ea in idautils.Functions())
               if name in ("NdrClientCall2", "NdrClientCall3", "NdrClientCall4")]
    for imp in idautils.Names():
        if imp[1].endswith(("NdrClientCall2", "NdrClientCall4")) and imp[0] not in targets:
            targets.append(imp[0])
    seen_desc = set()
    for t in targets:
        for x in idautils.XrefsTo(t):
            if not idc.print_insn_mnem(x.frm).upper().startswith("BL"):
                continue
            desc, fmt = _reg_value(x.frm, 0), _reg_value(x.frm, 1)
            caller = idc.get_func_name(x.frm)
            if desc and desc not in seen_desc:
                seen_desc.add(desc)
                ri = _dw(desc)
                print("stub desc 0x%X: interface %s v%d.%d, syntax %s, format types 0x%X"
                      % (desc, _guid(ri + 4), ida_bytes.get_word(ri + 20), ida_bytes.get_word(ri + 22),
                         _guid(ri + 24), _dw(desc + 0x20)))
            if not fmt:
                print("%s (0x%X): proc format not found" % (caller, x.frm))
                continue
            opnum, stack, params = _proc(fmt)
            callers = sorted({idc.get_func_name(y.frm) for y in idautils.XrefsTo(ida_funcs.get_func(x.frm).start_ea)
                              if idc.get_func_name(y.frm)})
            print("opnum %2d  %s (format 0x%X, stack %d)  called by %s" % (opnum, caller, fmt, stack, ", ".join(callers)))
            for p in params:
                print("          " + p)
