// -*- mode: C++; c-file-style: "cc-mode" -*-
//=============================================================================
//
// THIS MODULE IS PUBLICLY LICENSED
//
// Copyright 2001-2020 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.
//
// This is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
//=============================================================================
///
/// \file
/// \brief C++ Tracing in SIG Format
///
//=============================================================================
// SPDIFF_OFF

#ifndef _VERILATED_VCD_C_H_
#define _VERILATED_VCD_C_H_ 1

enum SigCmd
{
    SigCmd_None,
    SigCmd_DeclareSignal,
    SigCmd_TimeDelta8,
    SigCmd_TimeDelta16,
    SigCmd_TimeDelta32,
    SigCmd_TimeDelta64,
    SigCmd_Code8,
    SigCmd_Code16,
    SigCmd_Code32,
    SigCmd_Code64,
    SigCmd_ValZero,
    SigCmd_ValOne,
    SigCmd_ValNegOne,
	SigCmd_Val8,
	SigCmd_Val16,
	SigCmd_Val32,
	SigCmd_Val64,
    SigCmd_ValX,
	SigCmd_CodeValZero8,
    SigCmd_CodeValZero16,
    SigCmd_CodeValZero32,
    SigCmd_CodeValZero64,
	SigCmd_CodeValOne8,
    SigCmd_CodeValOne16,
    SigCmd_CodeValOne32,
    SigCmd_CodeValOne64,
    SigCmd_CodeSetString,
};

enum SigFlags
{
    SigFlags_None,
    SigFlags_Tri = 1,
    SigFlags_Bussed = 2,
    SigFlags_Array = 4
};


#include <verilatedos.h>
#include <verilated.h>

#include <map>
#include <string>
#include <vector>
#include <unordered_map>

class VerilatedVcd;
class VerilatedVcdCallInfo;

// SPDIFF_ON
//=============================================================================
// VerilatedFile
/// File handling routines, which can be overrode for e.g. socket I/O

#define VERILATED_BUFFER_SIZE 256*1024
#define VERILATED_BUFFER_LARGESIZE 32*1024
#define VERILATED_BUFFER_SAFEZONE 64*1024

class VerilatedVcdFile {
private:
    int m_fd;  ///< File descriptor we're writing to
    int mFileSize;
    uint8_t* mBufferHead;
    uint8_t* mBufferPtr;
    uint8_t* mBufferEnd;
    uint8_t* mBufferTrigger;

public:
    // METHODS
    VerilatedVcdFile()
        : m_fd(0)
    {
        mFileSize = 0;
        mBufferHead = new uint8_t[VERILATED_BUFFER_SIZE];
        mBufferPtr = mBufferHead;
        mBufferEnd = mBufferHead + VERILATED_BUFFER_SIZE;
        mBufferTrigger = mBufferEnd - VERILATED_BUFFER_SAFEZONE;
    }
    virtual ~VerilatedVcdFile()
    {
        delete mBufferHead;
    }

    virtual bool open(const std::string& name) VL_MT_UNSAFE;
    virtual void close() VL_MT_UNSAFE;
    virtual ssize_t writePhys(const void* bufp, ssize_t len);

    void write(const void* bufp, ssize_t len)
    {
        memcpy(mBufferPtr, bufp, len);
        mBufferPtr += len;
    }
    void write8(uint8_t val) { *(mBufferPtr++) = val; }
    void write16(uint16_t val) { *((*(uint16_t**)&mBufferPtr)++) = val; }
    void write32(uint32_t val) { *((*(uint32_t**)&mBufferPtr)++) = val; }
    void write64(uint64_t val) { *((*(uint64_t**)&mBufferPtr)++) = val; }
    void writeSized(const void* ptr, int len) { write32(len); write((const char*)ptr, len); }
    void writeVarLenCmd(uint8_t baseCmd, uint64_t value)
    {
		if (value < 0x100)
		{
			write8(baseCmd);
			write8((uint8_t)value);
		}
		else if (value < 0x10000)
		{
			write8(baseCmd + 1);
			write16((uint16_t)value);
		}
		else if (value < 0x100000000L)
		{
			write8(baseCmd + 2);
			write32((uint32_t)value);
		}
		else
		{
			write8(baseCmd + 3);
			write64(value);
		}
    }

	void flush()
	{
        if (mBufferPtr == mBufferHead)
            return;

        assert(mBufferPtr <= mBufferEnd);

        writePhys(mBufferHead, mBufferPtr - mBufferHead);
        mBufferPtr = mBufferHead;
	}

    void checkBuffer()
    {
        if (mBufferPtr >= mBufferTrigger)
            flush();
    }
};

//=============================================================================
// VerilatedVcdSig
/// Internal data on one signal being traced.

class VerilatedVcdSig {
protected:
    friend class VerilatedVcd;
    vluint32_t m_code;  ///< VCD file code number
    int m_bits;  ///< Size of value in bits
    VerilatedVcdSig(vluint32_t code, int bits)
        : m_code(code)
        , m_bits(bits) {}
public:
    ~VerilatedVcdSig() {}
};

//=============================================================================

typedef void (*VerilatedVcdCallback_t)(VerilatedVcd* vcdp, void* userthis, vluint32_t code);

//=============================================================================
// VerilatedVcd
/// Base class to create a Verilator VCD dump
/// This is an internally used class - see VerilatedVcdC for what to call from applications

class VerilatedVcd {
private:
    VerilatedVcdFile*   m_filep;        ///< File we're writing to
    bool                m_fileNewed;    ///< m_filep needs destruction
    bool                m_isOpen;       ///< True indicates open file
    bool                m_evcd;         ///< True for evcd format
    std::string         m_filename;     ///< Filename we're writing to (if open)
    char                m_scopeEscape;  ///< Character to separate scope components
    int                 m_modDepth;     ///< Depth of module hierarchy
    bool                m_fullDump;     ///< True indicates dump ignoring if changed
    vluint32_t          m_nextCode;     ///< Next code number to assign
    std::string         m_modName;      ///< Module name being traced now
    double              m_timeRes;      ///< Time resolution (ns/ms etc)
    double              m_timeUnit;     ///< Time units (ns/ms etc)
    vluint64_t          m_timeLastDump; ///< Last time we did a dump

    char*               m_wrBufp;       ///< Output buffer
    char*               m_wrFlushp;     ///< Output buffer flush trigger location
    vluint64_t          m_wrChunkSize;  ///< Output buffer size
    vluint64_t          m_wroteBytes;   ///< Number of bytes written to this file

    vluint32_t*         m_sigs_oldvalp; ///< Pointer to old signal values
    typedef std::vector<VerilatedVcdSig>  SigVec;
    SigVec              m_sigs;         ///< Pointer to signal information
    typedef std::vector<VerilatedVcdCallInfo*>  CallbackVec;
    CallbackVec         m_callbacks;    ///< Routines to perform dumping

    typedef std::unordered_map<std::string, uint32_t> NameToCodeMap;
    NameToCodeMap       mNameToCodeMap;

    VerilatedAssertOneThread m_assertOne;  ///< Assert only called from single thread

    void closePrev();
    void closeErr();
    void openNext();
    void declare(vluint32_t code, const char* name, const char* wirep, bool array, int arraynum,
                 bool tri, bool bussed, int msb, int lsb);

    void dumpPrep(vluint64_t timeui);
    void dumpFull(vluint64_t timeui);
    // cppcheck-suppress functionConst
    void dumpDone();

    void bufferFlush() { m_filep->flush(); }
    void bufferCheck() { m_filep->checkBuffer(); }

    // CONSTRUCTORS
    VL_UNCOPYABLE(VerilatedVcd);
public:
    explicit VerilatedVcd(VerilatedVcdFile* filep = NULL);
    ~VerilatedVcd();

    // ACCESSORS
    /// Set size in megabytes after which new file should be created
    void rolloverMB(vluint64_t rolloverMB) { }
    /// Is file open?
    bool isOpen() const { return m_isOpen; }
    /// Change character that splits scopes.  Note whitespace are ALWAYS escapes.
    void scopeEscape(char flag) { m_scopeEscape = flag; }
    /// Is this an escape?
    inline bool isScopeEscape(char c) { return isspace(c) || c == m_scopeEscape; }

    // METHODS
    void open(const char* filename) VL_MT_UNSAFE_ONE;  ///< Open the file; call isOpen() to see if errors
    void openNext(bool incFilename);  ///< Open next data-only file
    void close() VL_MT_UNSAFE_ONE;  ///< Close the file
    /// Flush any remaining data to this file
    void flush() VL_MT_UNSAFE_ONE { bufferFlush(); }
    /// Flush any remaining data from all files
    static void flush_all() VL_MT_UNSAFE_ONE;

    void set_time_unit(const char* unitp);  ///< Set time units (s/ms, defaults to ns)
    void set_time_unit(const std::string& unit) { set_time_unit(unit.c_str()); }

    void set_time_resolution(const char* unitp);  ///< Set time resolution (s/ms, defaults to ns)
    void set_time_resolution(const std::string& unit) { set_time_resolution(unit.c_str()); }

    double timescaleToDouble(const char* unitp);

    /// Inside dumping routines, called each cycle to make the dump
    void dump(vluint64_t timeui);
    /// Call dump with a absolute unscaled time in seconds
    void dumpSeconds(double secs) { dump(static_cast<vluint64_t>(secs * m_timeRes)); }

    /// Inside dumping routines, declare callbacks for tracings
    void addCallback(VerilatedVcdCallback_t initcb, VerilatedVcdCallback_t fullcb,
                     VerilatedVcdCallback_t changecb, void* userthis) VL_MT_UNSAFE_ONE;

    /// Inside dumping routines, declare a module
    void module(const std::string& name);
    /// Inside dumping routines, declare a signal
    void declBit(     vluint32_t code, const char* name, bool array, int arraynum);
    void declBus(     vluint32_t code, const char* name, bool array, int arraynum, int msb, int lsb);
    void declQuad(    vluint32_t code, const char* name, bool array, int arraynum, int msb, int lsb);
    void declArray(   vluint32_t code, const char* name, bool array, int arraynum, int msb, int lsb);
    void declTriBit(  vluint32_t code, const char* name, bool array, int arraynum);
    void declTriBus(  vluint32_t code, const char* name, bool array, int arraynum, int msb, int lsb);
    void declTriQuad( vluint32_t code, const char* name, bool array, int arraynum, int msb, int lsb);
    void declTriArray(vluint32_t code, const char* name, bool array, int arraynum, int msb, int lsb);
    void declDouble(  vluint32_t code, const char* name, bool array, int arraynum);
    void declFloat(   vluint32_t code, const char* name, bool array, int arraynum);

    void declString(vluint32_t code, const char* name, int numBits);
    void setString(vluint32_t code, int idx, const char* str);

    uint32_t FindCode(const std::string& name);

    //  ... other module_start for submodules (based on cell name)

    void WriteCode(uint32_t code)
    {
        m_filep->writeVarLenCmd(SigCmd_Code8, code);
    }

	void WriteVal(uint64_t val)
	{
        if (val == 0)
        {
            m_filep->write8(SigCmd_ValZero);
            return;
        }

		if (val == 1)
		{
			m_filep->write8(SigCmd_ValOne);
			return;
		}

        m_filep->writeVarLenCmd(SigCmd_Val8, val);
	}

    void WriteValBits(const uint8_t* valPtr, int bits)
    {
        WriteVal(*valPtr);
    }

    /// Inside dumping routines, dump one signal
    void fullBit(vluint32_t code, const vluint32_t newval) {
        // Note the &1, so we don't require clean input -- makes more common no change case faster
        m_sigs_oldvalp[code] = newval;
        //*m_writep++=('0'+static_cast<char>(newval&1)); printCode(code); *m_writep++='\n';

        if (newval == 0)
        {
            m_filep->writeVarLenCmd(SigCmd_CodeValZero8, code);
        }
        else if (newval == 1)
        {
            m_filep->writeVarLenCmd(SigCmd_CodeValOne8, code);
        }
        else
		{
			WriteCode(code);
			WriteVal(newval);
		}
        bufferCheck();
    }
    void fullBus(vluint32_t code, const vluint32_t newval, int bits)
    {
        m_sigs_oldvalp[code] = newval;
		if (newval == 0)
		{
			m_filep->writeVarLenCmd(SigCmd_CodeValZero8, code);
		}
		else if (newval == 1)
		{
			m_filep->writeVarLenCmd(SigCmd_CodeValOne8, code);
		}
		else
		{
			WriteCode(code);
			WriteVal(newval);
		}
        bufferCheck();
    }
    void fullQuad(vluint32_t code, const vluint64_t newval, int bits) {
        (*(reinterpret_cast<vluint64_t*>(&m_sigs_oldvalp[code]))) = newval;
		WriteCode(code);
		WriteVal(newval);
        bufferCheck();
    }
    void fullArray(vluint32_t code, const vluint32_t* newval, int bits) {
        for (int word = 0; word < (((bits - 1) / 32) + 1); ++word) {
            m_sigs_oldvalp[code + word] = newval[word];
        }
		WriteCode(code);
        WriteValBits((uint8_t*)newval, bits);
        bufferCheck();
    }
    void fullArray(vluint32_t code, const vluint64_t* newval, int bits) {
        for (int word = 0; word < (((bits - 1) / 64) + 1); ++word) {
            m_sigs_oldvalp[code + word] = newval[word];
        }
		WriteCode(code);
		WriteValBits((uint8_t*)newval, bits);
        bufferCheck();
    }
    void fullTriBit(vluint32_t code, const vluint32_t newval, const vluint32_t newtri) {
        m_sigs_oldvalp[code]   = newval;
        m_sigs_oldvalp[code+1] = newtri;
		WriteCode(code);
		WriteVal(newval);
        bufferCheck();
    }
    void fullTriBus(vluint32_t code, const vluint32_t newval, const vluint32_t newtri, int bits) {
        m_sigs_oldvalp[code] = newval;
        m_sigs_oldvalp[code+1] = newtri;
		WriteCode(code);
		WriteVal(newval);
        bufferCheck();
    }
    void fullTriQuad(vluint32_t code, const vluint64_t newval,
                     const vluint32_t newtri, int bits) {
        (*(reinterpret_cast<vluint64_t*>(&m_sigs_oldvalp[code]))) = newval;
        (*(reinterpret_cast<vluint64_t*>(&m_sigs_oldvalp[code+1]))) = newtri;
		WriteCode(code);
		WriteVal(newval);
        bufferCheck();
    }
    void fullTriArray(vluint32_t code, const vluint32_t* newvalp,
                      const vluint32_t* newtrip, int bits) {
        for (int word=0; word<(((bits-1)/32)+1); ++word) {
            m_sigs_oldvalp[code+word*2]   = newvalp[word];
            m_sigs_oldvalp[code+word*2+1] = newtrip[word];
        }
		WriteCode(code);
		WriteValBits((uint8_t*)newvalp, bits);
        bufferCheck();
    }
    void fullDouble(vluint32_t code, const double newval);
    void fullFloat(vluint32_t code, const float newval);

    /// Inside dumping routines, dump one signal as unknowns
    /// Presently this code doesn't change the oldval vector.
    /// Thus this is for special standalone applications that after calling
    /// fullBitX, must when then value goes non-X call fullBit.
    inline void fullBitX(vluint32_t code) {
        //*m_writep++='x'; printCode(code); *m_writep++='\n';
        //bufferCheck();
    }
    inline void fullBusX(vluint32_t code, int bits) {
        /**m_writep++='b';
        for (int bit=bits-1; bit>=0; --bit) {
            *m_writep++='x';
        }
        *m_writep++=' '; printCode(code); *m_writep++='\n';
        bufferCheck();*/
    }
    inline void fullQuadX(vluint32_t code, int bits) { fullBusX(code, bits); }
    inline void fullArrayX(vluint32_t code, int bits) { fullBusX(code, bits); }

    /// Inside dumping routines, dump one signal if it has changed
    inline void chgBit(vluint32_t code, const vluint32_t newval)
    {
        vluint32_t diff = m_sigs_oldvalp[code] ^ newval;
        if (VL_UNLIKELY(diff))
        {
            // Verilator 3.510 and newer provide clean input, so the below
            // is only for back compatibility
            if (VL_UNLIKELY(diff & 1)) {  // Change after clean?
                fullBit(code, newval);
            }
        }
    }
    inline void chgBus(vluint32_t code, const vluint32_t newval, int bits) {
        vluint32_t diff = m_sigs_oldvalp[code] ^ newval;
        if (VL_UNLIKELY(diff)) {
            if (VL_UNLIKELY(bits == 32 || (diff & ((1U << bits) - 1)))) {
                fullBus(code, newval, bits);
            }
        }
    }
    inline void chgQuad(vluint32_t code, const vluint64_t newval, int bits)
    {
        vluint64_t diff = (*(reinterpret_cast<vluint64_t*>(&m_sigs_oldvalp[code]))) ^ newval;
        if (VL_UNLIKELY(diff))
        {
            if (VL_UNLIKELY(bits == 64 || (diff & ((VL_ULL(1) << bits) - 1))))
            {
                fullQuad(code, newval, bits);
            }
        }
    }
	inline void chgArray(vluint32_t code, const vluint16_t* newval, int elemBits, int arrayLen)
	{
		//for (int word = 0; word < (((bits - 1) / 16) + 1); ++word)

        for (int i = 0; i < arrayLen; i++)
		{
			if (VL_UNLIKELY(m_sigs_oldvalp[code + arrayLen] ^ newval[i]))
			{
				//fullArray(code, newval, bits);
				return;
			}
		}
	}
    inline void chgArray(vluint32_t code, const vluint32_t* newval, int bits)
    {
        for (int word = 0; word < (((bits - 1) / 32) + 1); ++word)
        {
            if (VL_UNLIKELY(m_sigs_oldvalp[code + word] ^ newval[word]))
            {
                fullArray(code, newval, bits);
                return;
            }
        }
    }
    inline void chgArray(vluint32_t code, const vluint64_t* newval, int bits)
    {
        for (int word = 0; word < (((bits - 1) / 64) + 1); ++word)
        {
            if (VL_UNLIKELY(m_sigs_oldvalp[code + word] ^ newval[word]))
            {
                fullArray(code, newval, bits);
                return;
            }
        }
    }
    inline void chgTriBit(vluint32_t code, const vluint32_t newval,
                          const vluint32_t newtri)
    {
        vluint32_t diff = ((m_sigs_oldvalp[code] ^ newval)
                         | (m_sigs_oldvalp[code+1] ^ newtri));
        if (VL_UNLIKELY(diff))
        {
            // Verilator 3.510 and newer provide clean input, so the below
            // is only for back compatibility
            if (VL_UNLIKELY(diff & 1))
            {  // Change after clean?
                fullTriBit(code, newval, newtri);
            }
        }
    }
    inline void chgTriBus(vluint32_t code, const vluint32_t newval,
                          const vluint32_t newtri, int bits) {
        vluint32_t diff = ((m_sigs_oldvalp[code] ^ newval)
                         | (m_sigs_oldvalp[code+1] ^ newtri));
        if (VL_UNLIKELY(diff)) {
            if (VL_UNLIKELY(bits==32 || (diff & ((1U<<bits)-1) ))) {
                fullTriBus(code, newval, newtri, bits);
            }
        }
    }
    inline void chgTriQuad(vluint32_t code, const vluint64_t newval,
                           const vluint32_t newtri, int bits) {
        vluint64_t diff = ( ((*(reinterpret_cast<vluint64_t*>(&m_sigs_oldvalp[code]))) ^ newval)
                            | ((*(reinterpret_cast<vluint64_t*>(&m_sigs_oldvalp[code+1]))) ^ newtri));
        if (VL_UNLIKELY(diff)) {
            if (VL_UNLIKELY(bits == 64 || (diff & ((VL_ULL(1) << bits) - 1)))) {
                fullTriQuad(code, newval, newtri, bits);
            }
        }
    }
    inline void chgTriArray(vluint32_t code, const vluint32_t* newvalp,
                            const vluint32_t* newtrip, int bits) {
        for (int word=0; word<(((bits-1)/32)+1); ++word) {
            if (VL_UNLIKELY((m_sigs_oldvalp[code+word*2] ^ newvalp[word])
                            | (m_sigs_oldvalp[code+word*2+1] ^ newtrip[word]))) {
                fullTriArray(code,newvalp,newtrip,bits);
                return;
            }
        }
    }
    inline void chgDouble(vluint32_t code, const double newval) {
        // cppcheck-suppress invalidPointerCast
        if (VL_UNLIKELY((*(reinterpret_cast<double*>(&m_sigs_oldvalp[code]))) != newval)) {
            fullDouble(code, newval);
        }
    }
    inline void chgFloat(vluint32_t code, const float newval) {
        // cppcheck-suppress invalidPointerCast
        if (VL_UNLIKELY((*(reinterpret_cast<float*>(&m_sigs_oldvalp[code]))) != newval)) {
            fullFloat(code, newval);
        }
    }

protected:
    // METHODS
    void evcd(bool flag) { m_evcd = flag; }
};

//=============================================================================
// VerilatedVcdC
/// Create a VCD dump file in C standalone (no SystemC) simulations.
/// Also derived for use in SystemC simulations.
/// Thread safety: Unless otherwise indicated, every function is VL_MT_UNSAFE_ONE

class VerilatedVcdC
{
    VerilatedVcd m_sptrace;  ///< Trace file being created

    // CONSTRUCTORS
    VL_UNCOPYABLE(VerilatedVcdC);
public:
    explicit VerilatedVcdC(VerilatedVcdFile* filep = NULL)
        : m_sptrace(filep) {}
    ~VerilatedVcdC() {}
public:
    // ACCESSORS
    /// Is file open?
    bool isOpen() const { return m_sptrace.isOpen(); }
    // METHODS
    /// Open a new VCD file
    /// This includes a complete header dump each time it is called,
    /// just as if this object was deleted and reconstructed.
    void open(const char* filename) VL_MT_UNSAFE_ONE { m_sptrace.open(filename); }
    /// Continue a VCD dump by rotating to a new file name
    /// The header is only in the first file created, this allows
    /// "cat" to be used to combine the header plus any number of data files.
    void openNext(bool incFilename = true) VL_MT_UNSAFE_ONE { m_sptrace.openNext(incFilename); }
    /// Set size in megabytes after which new file should be created
    void rolloverMB(size_t rolloverMB) { m_sptrace.rolloverMB(rolloverMB); }
    /// Close dump
    void close() VL_MT_UNSAFE_ONE { m_sptrace.close(); }
    /// Flush dump
    void flush() VL_MT_UNSAFE_ONE { m_sptrace.flush(); }
    /// Write one cycle of dump data
    void dump(vluint64_t timeui) { m_sptrace.dump(timeui); }
    /// Write one cycle of dump data - backward compatible and to reduce
    /// conversion warnings.  It's better to use a vluint64_t time instead.
    void dump(double timestamp) { dump(static_cast<vluint64_t>(timestamp)); }
    void dump(vluint32_t timestamp) { dump(static_cast<vluint64_t>(timestamp)); }
    void dump(int timestamp) { dump(static_cast<vluint64_t>(timestamp)); }
    /// Set time units (s/ms, defaults to ns)
    /// See also VL_TIME_PRECISION, and VL_TIME_MULTIPLIER in verilated.h
    void set_time_unit(const char* unit) { m_sptrace.set_time_unit(unit); }
    void set_time_unit(const std::string& unit) { set_time_unit(unit.c_str()); }
    /// Set time resolution (s/ms, defaults to ns)
    /// See also VL_TIME_PRECISION, and VL_TIME_MULTIPLIER in verilated.h
    void set_time_resolution(const char* unit) { m_sptrace.set_time_resolution(unit); }
    void set_time_resolution(const std::string& unit) { set_time_resolution(unit.c_str()); }

    /// Internal class access
    inline VerilatedVcd* spTrace() { return &m_sptrace; }
};

#endif  // guard
