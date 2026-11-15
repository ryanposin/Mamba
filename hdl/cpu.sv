//Inputs: clk, reset, nonmaskable interrupt, interrupt[2:0], memory wait state insert, memory bus input
//Output: interrupt acknowledge, memory bus output, write address, read address, read request, write request, write bus width, read bus width
module processor_core(input logic clk, input logic reset, input logic nonmi, input logic[2:0] intin, input logic readwait,
				output logic intack,
                                output logic[31:0] membuso, input logic[31:0] membusi,
                                output logic[31:0] writeaddr, readaddr,
                                output logic datareq, output logic datasend, output logic[1:0] membuswidth, output logic[1:0] readmembuswidth);

	logic perftimersel, instreqfetch, prefetchstallpipe, addinst, prefetchwait, mode, ucodereset, memfinished, pspreset, noteq, pccondout, rawpcwe, lt, eq, condpc, internalreset, qfull, memreq, memreqdir, incprefetch, memwait, instreq, pipeready, pcinc, pcdec, pspinc, pspdec, sspinc, sspdec, spwe, pcwe, regwe, stalldispatchexec, stalldispatchmem, addrsel, datasel, requestdbus, dbusreqdir, dbusdir, dbusreq, pamux_ext, pbmux_ext, newmicrocode, qempty, incpcfetch, breset, feq, fneq, flt, ppas, injectinst, nmilatched, inten, sspwe, pspwe;
	logic[1:0] immsel, pbmuxs, funcsel, wbmuxsel, pccond, ppbs, pamuxs, perfsel;
	logic[2:0] intlatched;
	logic[3:0] regtowriteo;
	logic[4:0] executec;
	logic[6:0] opcode_pointer, opcode_pointero, injectpointer;
	logic[15:0] immediate;
	logic[49:0] icodeo, icode;
	logic[31:0] immediate32, memaddr, programcounter, toprefetch, tofetch, insout, writeback, programstackpointer, supervisorstackpointer, rega, regb, immsignextend, currentsp, outmuxa, outmuxb, ao, bo, execout, memout, pipea, pipeb, pcchain, programcounterinst, programcountero;
	logic[31:0] memdatao, memdataexec, memdatatemp;
	logic[31:0] memdatai;
	logic[31:0] portain, tempimm, aforward, bforward, intaddr, stallcounter, instructioncount, cyclecount, perfout, pipeaout, privaddr, privaddrlatched, intaddrlatched;
	logic[1:0] buswidth;
	microcode_rom microcode2({1'b0, opcode_pointer}, icode);
	always_ff @(posedge clk)
		{feq, fneq, flt} <= {eq, noteq, lt};
	always_ff @(posedge clk)
		if (opcode_pointer >= 46 & opcode_pointer <= 64 & pipeready)
			tempimm <= {{16{insout[31]}},insout[31:20],insout[11:8]};
	always_ff @(posedge clk)
		if (opcode_pointero == 91 | opcode_pointero == 92)
			inten <= icodeo[47];

	always_comb
		begin
		    //Microcode driven signals
			regwe = stalldispatchmem ? 0 : icodeo[0];
			pcinc = incpcfetch;
			pcdec = icodeo[2];
			pspinc = mode ? icodeo[3] : 1'b0;
			sspinc = mode ? 1'b0 : icodeo[3];
			pspdec = mode ? icodeo[4] : 1'b0;
			sspdec = mode ? 1'b0 : icodeo[4];
			pspwe = mode ?  icodeo[5] : 1'b0;
			sspwe = mode ? 1'b0 : icodeo[5];
			pamuxs = icode[7:6];
			pbmuxs = icode[9:8];
			addrsel = icodeo[10];
			datasel = icodeo[11];
			requestdbus = icodeo[12];
			dbusreqdir = icodeo[13];
			wbmuxsel = icodeo[15:14];
			funcsel = icodeo[17:16];
			immsel = icode[34:33];
			condpc = icodeo[35];
			pccond = icodeo[37:36];
			ucodereset = icodeo[38];
			pspreset = icodeo[39];
			rawpcwe = icodeo[40];
			ppas = icodeo[42];
			ppbs = icodeo[44:43];
			buswidth = icodeo[46:45];
			intack = icodeo[47];
			perftimersel = icodeo[49];
			pcwe = condpc ? pccondout : rawpcwe;
			internalreset = ~reset | ucodereset;
			noteq = ~eq;
			pipeready = ~(stalldispatchmem | stalldispatchexec | prefetchstallpipe);
			newmicrocode = icodeo[32];
			
			//Interrupt acknowledge output logic
			if (opcode_pointero == injectpointer & injectinst)
			 intack = 1;
			else
			 intack = 0;
	end
	
	//Privilege mode logic 
	always_ff @(posedge clk)
	        if (internalreset)
	           mode <= 0;
	        else
			if (icodeo[41] & ({1'b0,opcode_pointer} == 8'h0F))
				mode <= 0;
			else if (icodeo[41] & ({1'b0,opcode_pointer} == 8'h70))
				mode <= 1;
	
	fourinmux #(32) pccondmux(feq, fneq, flt, flt | feq, pccond, pccondout);
	
	//Inputs: clk, reset, request instruction, memory access unit request, memory request direction, program counter input, bus width request input
	//Outputs: prefetch instruction out, instruction fetch not ready, memory access not ready, increment prefetch unit, memory access finished, program counter chain to prefetch
	//Memory bus signals memdatai/o, membusi/o, write address, read address, read valid, write valid, write width, read width  
	 busunit systembus(clk, internalreset | pcwe, addinst, memreq, memreqdir, memaddr, programcounter, buswidth, readwait,
                toprefetch, prefetchwait, memwait, incpcfetch, memfinished, pcchain,
                memdatai, memdatao,
                membuso, membusi,
                writeaddr, readaddr,
                datareq, datasend, membuswidth, readmembuswidth);

	//Inputs: clk, reset, bus not ready, stall ahead in pipe, instruction input program counter input
	//Outputs: prefetch empty, request instruction from bus, current instruction, program counter chain
	prefetcher prefetch(clk, internalreset | pcwe, prefetchwait, pipeready & ~injectinst, toprefetch, pcchain,
								prefetchstallpipe, addinst, insout, programcounterinst);
	
	
	//Input: clk, reset, increment, decrement, write enable, data in
	//Output: q output
	ma10k_special_reg pc(clk, internalreset, pcinc, pcdec, pcwe, writeback, programcounter);
	ma10k_special_reg psp(clk, internalreset | pspreset, pspinc, pspdec, pspwe, writeback, programstackpointer);
	ma10k_special_reg ssp(clk, internalreset, sspinc, sspdec, sspwe, writeback, supervisorstackpointer);
	

	always_ff @(posedge clk)
	   if (internalreset | cyclecount == 32'hFFFFFFFF)
	       begin
	           cyclecount <= 0;
	           stallcounter <= 0;
	           instructioncount <= 0;
	       end
	   else
	       begin
	           cyclecount <= cyclecount + 32'b1;
	          
	           if (pipeready & ~injectinst)
	               instructioncount <= instructioncount + 32'b1;
	           if (stalldispatchmem | stalldispatchexec | prefetchstallpipe)
	               stallcounter <= stallcounter + 32'b1;
	       end
	   
	
	always_comb currentsp = mode ? programstackpointer : supervisorstackpointer;
	
	//Inputs: instruction
	//Outputs: immediate[15:0], opcode_pointer[6:0]
	ma10k_frontend decoder(insout,
									immediate, opcode_pointer);
	
	//Inputs: current instruction, interrupt input, nmi input, current execution mode, interrupt mode
	//Outputs: Inject privilege/interrupt, microcode pointer to inject, interrupt vector, privilege violation vector
	interruptprivilage intprivarbiter(insout[19:12], intin, nonmi, mode, inten,
				injectinst, injectpointer, intaddr, privaddr);

	//Input: clk, reset, portasel, portbsel, writesel, writeenable, writeinput[31:0]
	//Output: a, b 
	regfile registers(clk, internalreset, insout[7:4], insout[3:0], regtowriteo, regwe, writeback,
							rega, regb);
	
	//Port A and Port B muxes
	fourinmux immmux({16'b0,immediate},{immediate,16'b0}, {{16{immediate[15]}},immediate[15:0]}, 0, immsel, immediate32);
	fourinmux pamux(rega, programcounterinst, {rega[31:16],16'b0}, {16'b0,rega[15:0]}, pamuxs, outmuxa);
	fourinmux pbmux(regb, immediate32, currentsp, programcounterinst, pbmuxs, outmuxb);


	//Pipeline forwarding
	always_comb
		if (insout[3:0] == regtowriteo & regtowriteo != 0 & opcode_pointero < 46 & opcode_pointero > 64)
			begin
				aforward = writeback;
				bforward = outmuxb;
			end
		else if (insout[7:4] == regtowriteo & regtowriteo != 0 & opcode_pointero < 46 & opcode_pointero > 64)
			begin
				aforward = outmuxa;
				bforward = writeback;
			end
		else
			begin
				aforward = outmuxa;
				bforward = outmuxb;
			end

    //Performance timers input
	fourinmux perfmux(stallcounter, instructioncount, cyclecount, stallcounter, immediate32[1:0], perfout);
	
	//Port A or performance timers
	twoinmux prepipeperf(aforward, perfout, perftimersel, portain);

	//Inputs: clk, reset, stall, microcode pointer, a, b, regtowrite, current program counter, interrupt vector, privilege vector
	//Outputs: opcode pointer output, port a out, port b out, destination register output, program counter out, interrupt vector out, privilege vector out
	pipebreak pipestage01(clk, internalreset | pcwe, ~pipeready | pcwe, (injectinst ? injectpointer : opcode_pointer), portain, bforward, insout[11:8], programcounterinst, intaddr, privaddr,
															opcode_pointero, ao, bo, regtowriteo, programcountero, intaddrlatched, privaddrlatched);
	
	//Grab PC or port A
	twoinmux postpipea(ao, programcountero, ppas, pipeaout);
	
	//Grab port B or latched immediate
	fourinmux postpipeb(bo, tempimm, intaddrlatched, privaddrlatched, ppbs, pipeb);
	//Inputs: clk, reset, reset microcode counter, function selection, port a input, port b input, opcode pointer, memory access unit stall
	//Outputs: execout, multi-cycle instruction stall, less than, equal to, microcode counter output, microcode output
	execute_unit exec(clk, internalreset, newmicrocode, funcsel, pipeaout, pipeb, opcode_pointero, stalldispatchmem,
														execout, stalldispatchexec, lt, eq, executec, icodeo);
														
	//Inputs: Execution unit connection, port b, address source select, data source select, databus request (from microcode), memory bus wait, memory bus cycle finished, input from memory bus
	//Outputs: Request memory bus, request direction, memory address, data to write, memory unit stall, output to memory bus
	//Inout: data
	mem_access_unit memaccess(execout, pipeb, addrsel, datasel, requestdbus, dbusreqdir, memwait, memfinished,
																				memreq, memreqdir, memaddr, memout, stalldispatchmem,
																				memdatai, memdatao);
	
	//Writeback multiplexer
	fourinmux wbmux(execout, memout, bo, 0, wbmuxsel, writeback);
								
endmodule
