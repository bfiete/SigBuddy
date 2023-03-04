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
/// \brief C++ Tracing in VCD Format
///
//=============================================================================
// SPDIFF_OFF

#include <verilatedos.h>
#include <verilated.h>
#include "verilated_vcd_c.h"

#include <algorithm>
#include <cerrno>
#include <ctime>
#include <fcntl.h>
#include <sys/stat.h>

#if defined(_WIN32) && !defined(__MINGW32__) && !defined(__CYGWIN__)
# include <io.h>
#else
# include <unistd.h>
#endif

// SPDIFF_ON

#ifndef O_LARGEFILE  // For example on WIN32
# define O_LARGEFILE 0
#endif
#ifndef O_NONBLOCK
# define O_NONBLOCK 0
#endif
#ifndef O_CLOEXEC
# define O_CLOEXEC 0
#endif

//=============================================================================
// VerilatedVcdImp
/// Base class to hold some static state
/// This is an internally used class

class VerilatedVcdSingleton {
private:
	typedef std::vector<VerilatedVcd*> VcdVec;
	struct Singleton {
		VerilatedMutex  s_vcdMutex;  ///< Protect the singleton
		VcdVec          s_vcdVecp VL_GUARDED_BY(s_vcdMutex);  ///< List of all created traces
	};
	static Singleton& singleton() { static Singleton s; return s; }
public:
	static void pushVcd(VerilatedVcd* vcdp) VL_EXCLUDES(singleton().s_vcdMutex) {
		VerilatedLockGuard lock(singleton().s_vcdMutex);
		singleton().s_vcdVecp.push_back(vcdp);
	}
	static void removeVcd(const VerilatedVcd* vcdp) VL_EXCLUDES(singleton().s_vcdMutex) {
		VerilatedLockGuard lock(singleton().s_vcdMutex);
		VcdVec::iterator pos = find(singleton().s_vcdVecp.begin(),
			singleton().s_vcdVecp.end(), vcdp);
		if (pos != singleton().s_vcdVecp.end()) { singleton().s_vcdVecp.erase(pos); }
	}
	static void flush_all() VL_EXCLUDES(singleton().s_vcdMutex) VL_MT_UNSAFE_ONE {
		// Thread safety: Although this function is protected by a mutex so
		// perhaps in the future we can allow tracing in separate threads,
		// vcdp->flush() assumes call from single thread
		VerilatedLockGuard lock(singleton().s_vcdMutex);
		for (VcdVec::const_iterator it = singleton().s_vcdVecp.begin();
			it != singleton().s_vcdVecp.end(); ++it) {
			VerilatedVcd* vcdp = *it;
			vcdp->flush();
		}
	}
};

//=============================================================================
// VerilatedVcdCallInfo
/// Internal callback routines for each module being traced.
////
/// Each module that wishes to be traced registers a set of
/// callbacks stored in this class.  When the trace file is being
/// constructed, this class provides the callback routines to be executed.

class VerilatedVcdCallInfo {
protected:
	friend class VerilatedVcd;
	VerilatedVcdCallback_t      m_initcb;       ///< Initialization Callback function
	VerilatedVcdCallback_t      m_fullcb;       ///< Full Dumping Callback function
	VerilatedVcdCallback_t      m_changecb;     ///< Incremental Dumping Callback function
	void* m_userthis;     ///< Fake "this" for caller
	vluint32_t          m_code;         ///< Starting code number
	// CONSTRUCTORS
	VerilatedVcdCallInfo(VerilatedVcdCallback_t icb, VerilatedVcdCallback_t fcb,
		VerilatedVcdCallback_t changecb,
		void* ut, vluint32_t code)
		: m_initcb(icb), m_fullcb(fcb), m_changecb(changecb), m_userthis(ut), m_code(code) {}
	~VerilatedVcdCallInfo() {}
};

//=============================================================================
//=============================================================================
//=============================================================================
// VerilatedVcdFile

bool VerilatedVcdFile::open(const std::string& name) VL_MT_UNSAFE
{
	m_fd = ::open(name.c_str(), O_CREAT | O_WRONLY | O_TRUNC | O_LARGEFILE | O_NONBLOCK | O_CLOEXEC | O_BINARY, 0666);
	return (m_fd >= 0);
}

void VerilatedVcdFile::close() VL_MT_UNSAFE
{
	::close(m_fd);
}

ssize_t VerilatedVcdFile::writePhys(const void* bufp, ssize_t len) VL_MT_UNSAFE
{
	mFileSize += len;
	if (mFileSize >= 65)
	{
		int a = 123;
	}

	return ::write(m_fd, bufp, len);
}

//=============================================================================
//=============================================================================
//=============================================================================
// Opening/Closing

VerilatedVcd::VerilatedVcd(VerilatedVcdFile* filep)
	: m_isOpen(false), m_modDepth(0), m_nextCode(1)
{
	// Not in header to avoid link issue if header is included without this .cpp file
	m_fileNewed = (filep == NULL);
	m_filep = m_fileNewed ? new VerilatedVcdFile : filep;
	m_timeRes = m_timeUnit = 1e-9;
	m_timeLastDump = 0;
	m_sigs_oldvalp = NULL;
	m_evcd = false;
	m_scopeEscape = '.';  // Backward compatibility
	m_fullDump = true;
	m_wrChunkSize = 8 * 1024;
	m_wrBufp = new char[m_wrChunkSize * 8];
	m_wrFlushp = m_wrBufp + m_wrChunkSize * 6;
	m_wroteBytes = 0;
}

void VerilatedVcd::open(const char* filename)
{
	m_assertOne.check();
	if (isOpen()) return;

	// Set member variables
	m_filename = filename;
	VerilatedVcdSingleton::pushVcd(this);

	// SPDIFF_OFF
	// Set callback so an early exit will flush us
	Verilated::flushCb(&flush_all);

	m_assertOne.check();
	closePrev();  // Close existing
	if (!m_filep->open(m_filename))
	{
        // User code can check isOpen()
        m_isOpen = false;
	}
	else
	{
		m_isOpen = true;
	}

	m_fullDump = true;  // First dump must be full
	m_wroteBytes = 0;

	// SPDIFF_ON
	if (!isOpen()) return;

	m_filep->write32('BGIS');
	m_filep->write32(1);

	m_filep->write(&m_timeRes, sizeof(m_timeRes));
	m_filep->write(&m_timeUnit, sizeof(m_timeUnit));

	m_nextCode = 1;
	for (vluint32_t ent = 0; ent < m_callbacks.size(); ent++)
	{
		VerilatedVcdCallInfo* cip = m_callbacks[ent];
		cip->m_code = m_nextCode;
		(cip->m_initcb)(this, cip->m_userthis, cip->m_code);
	}

	// Allocate space now we know the number of codes
	if (!m_sigs_oldvalp)
	{
		m_sigs_oldvalp = new vluint32_t[m_nextCode + 10];
	}
}

VerilatedVcd::~VerilatedVcd()
{
	close();
	if (m_wrBufp) { delete[] m_wrBufp; m_wrBufp = NULL; }
	if (m_sigs_oldvalp) { delete[] m_sigs_oldvalp; m_sigs_oldvalp = NULL; }
	if (m_filep && m_fileNewed) { delete m_filep; m_filep = NULL; }
	for (CallbackVec::const_iterator it = m_callbacks.begin(); it != m_callbacks.end(); ++it)
	{
		delete (*it);
	}
	m_callbacks.clear();
	VerilatedVcdSingleton::removeVcd(this);
}

void VerilatedVcd::closePrev()
{
	// This function is on the flush() call path
	if (!isOpen()) return;

	bufferFlush();
	m_isOpen = false;
	m_filep->close();
}

void VerilatedVcd::closeErr()
{
	// This function is on the flush() call path
	// Close due to an error.  We might abort before even getting here,
	// depending on the definition of vl_fatal.
	if (!isOpen()) return;

	// No buffer flush, just fclose
	m_isOpen = false;
	m_filep->close();  // May get error, just ignore it
}

void VerilatedVcd::close() {
	// This function is on the flush() call path
	m_assertOne.check();
	if (!isOpen()) return;
	if (m_evcd) {
	}
	closePrev();
}

//=============================================================================
// Simple methods

void VerilatedVcd::set_time_unit(const char* unitp) {
	//cout<<" set_time_unit("<<unitp<<") == "<<timescaleToDouble(unitp)
	//    <<" == "<<doubleToTimescale(timescaleToDouble(unitp))<<endl;
	m_timeUnit = timescaleToDouble(unitp);
}

void VerilatedVcd::set_time_resolution(const char* unitp) {
	//cout<<"set_time_resolution("<<unitp<<") == "<<timescaleToDouble(unitp)
	//    <<" == "<<doubleToTimescale(timescaleToDouble(unitp))<<endl;
	m_timeRes = timescaleToDouble(unitp);
}

double VerilatedVcd::timescaleToDouble(const char* unitp) {
	char* endp;
	double value = strtod(unitp, &endp);
	if (value == 0.0 && endp == unitp) value = 1;  // On error so we allow just "ns" to return 1e-9.
	unitp = endp;
	while (*unitp && isspace(*unitp)) unitp++;
	switch (*unitp) {
	case 's': value *= 1e1; break;
	case 'm': value *= 1e-3; break;
	case 'u': value *= 1e-6; break;
	case 'n': value *= 1e-9; break;
	case 'p': value *= 1e-12; break;
	case 'f': value *= 1e-15; break;
	case 'a': value *= 1e-18; break;
	}
	return value;
}

//=============================================================================
// Definitions

void VerilatedVcd::module(const std::string& name) {
	m_assertOne.check();
	m_modName = name;
}

void VerilatedVcd::declare(vluint32_t code, const char* name, const char* wirep,
	bool array, int arraynum, bool tri, bool bussed, int msb, int lsb)
{
	if (!code)
	{
		VL_FATAL_MT(__FILE__, __LINE__, "",
			"Internal: internal trace problem, code 0 is illegal");
	}

	int bits = ((msb > lsb) ? (msb - lsb) : (lsb - msb)) + 1;
	int codesNeeded = 1 + int(bits / 32);
	if (tri) codesNeeded *= 2;  // Space in change array for __en signals

	if (array)
		codesNeeded *= arraynum;

	// Make sure array is large enough
	m_nextCode = std::max(m_nextCode, code + codesNeeded);
	if (m_sigs.capacity() <= m_nextCode)
	{
		m_sigs.reserve(m_nextCode * 2);  // Power-of-2 allocation speeds things up
	}

	// Save declaration info
	VerilatedVcdSig sig = VerilatedVcdSig(code, bits);
	m_sigs.push_back(sig);

	SigFlags sigFlags = SigFlags_None;

	if (array)
		sigFlags = (SigFlags)(sigFlags | SigFlags_Array);

	m_filep->write8(SigCmd_DeclareSignal);
	m_filep->write8(sigFlags);
	m_filep->write32(code);
	m_filep->writeSized((uint8_t*)name, strlen(name));
	m_filep->writeSized((uint8_t*)wirep, strlen(wirep));
	m_filep->write32(lsb);
	m_filep->write32(msb);
	if (array)
		m_filep->write32(arraynum);

	mNameToCodeMap[name] = code;

	bufferCheck();
}

void VerilatedVcd::declBit(vluint32_t code, const char* name, bool array, int arraynum) {
	declare(code, name, "wire", array, arraynum, false, false, 0, 0);
}
void VerilatedVcd::declBus(vluint32_t code, const char* name, bool array, int arraynum, int msb,
	int lsb) {
	declare(code, name, "wire", array, arraynum, false, true, msb, lsb);
}
void VerilatedVcd::declQuad(vluint32_t code, const char* name, bool array, int arraynum, int msb,
	int lsb) {
	declare(code, name, "wire", array, arraynum, false, true, msb, lsb);
}
void VerilatedVcd::declArray(vluint32_t code, const char* name, bool array, int arraynum, int msb,
	int lsb) {
	declare(code, name, "wire", array, arraynum, false, true, msb, lsb);
}
void VerilatedVcd::declTriBit(vluint32_t code, const char* name, bool array, int arraynum) {
	declare(code, name, "wire", array, arraynum, true, false, 0, 0);
}
void VerilatedVcd::declTriBus(vluint32_t code, const char* name, bool array, int arraynum, int msb,
	int lsb) {
	declare(code, name, "wire", array, arraynum, true, true, msb, lsb);
}
void VerilatedVcd::declTriQuad(vluint32_t code, const char* name, bool array, int arraynum,
	int msb, int lsb) {
	declare(code, name, "wire", array, arraynum, true, true, msb, lsb);
}
void VerilatedVcd::declTriArray(vluint32_t code, const char* name, bool array, int arraynum,
	int msb, int lsb) {
	declare(code, name, "wire", array, arraynum, true, true, msb, lsb);
}
void VerilatedVcd::declFloat(vluint32_t code, const char* name, bool array, int arraynum) {
	declare(code, name, "real", array, arraynum, false, false, 31, 0);
}
void VerilatedVcd::declDouble(vluint32_t code, const char* name, bool array, int arraynum) {
	declare(code, name, "real", array, arraynum, false, false, 63, 0);
}

void VerilatedVcd::declString(vluint32_t code, const char* name, int numBits)
{
	declare(code, name, "string", false, 0, false, false, numBits - 1, 0);
}

void VerilatedVcd::setString(vluint32_t code, int idx, const char* str)
{
	WriteCode(code);
	m_filep->write8(SigCmd_CodeSetString);
	m_filep->write32(idx);
	m_filep->writeSized(str, strlen(str));
}

uint32_t VerilatedVcd::FindCode(const std::string& name)
{
	auto itr = mNameToCodeMap.find(name);
	if (itr == mNameToCodeMap.end())
		return 0;
	return itr->second;
}

//=============================================================================

void VerilatedVcd::fullDouble(vluint32_t code, const double newval)
{

}

void VerilatedVcd::fullFloat(vluint32_t code, const float newval)
{

}

//=============================================================================
// Callbacks

void VerilatedVcd::addCallback(VerilatedVcdCallback_t initcb, VerilatedVcdCallback_t fullcb, VerilatedVcdCallback_t changecb, void* userthis) VL_MT_UNSAFE_ONE
{
	m_assertOne.check();
	if (VL_UNLIKELY(isOpen()))
	{
		std::string msg = std::string("Internal: ") + __FILE__ + "::" + __FUNCTION__
			+ " called with already open file";
		VL_FATAL_MT(__FILE__, __LINE__, "", msg.c_str());
	}
	VerilatedVcdCallInfo* vci
		= new VerilatedVcdCallInfo(initcb, fullcb, changecb, userthis, m_nextCode);
	m_callbacks.push_back(vci);
}

//=============================================================================
// Dumping

void VerilatedVcd::dumpFull(vluint64_t timeui)
{
	m_assertOne.check();
	dumpPrep(timeui);
	Verilated::quiesce();
	for (vluint32_t ent = 0; ent < m_callbacks.size(); ent++) {
		VerilatedVcdCallInfo* cip = m_callbacks[ent];
		(cip->m_fullcb)(this, cip->m_userthis, cip->m_code);
	}
}

void VerilatedVcd::dump(vluint64_t timeui)
{
	m_assertOne.check();
	if (!isOpen()) return;
	if (VL_UNLIKELY(m_fullDump))
	{
		m_fullDump = false;  // No need for more full dumps
		dumpFull(timeui);
		return;
	}
	dumpPrep(timeui);
	Verilated::quiesce();
	for (vluint32_t ent = 0; ent < m_callbacks.size(); ++ent) {
		VerilatedVcdCallInfo* cip = m_callbacks[ent];
		(cip->m_changecb)(this, cip->m_userthis, cip->m_code);
	}
}

void VerilatedVcd::dumpPrep(vluint64_t timeui)
{
	// VCD file format specification does not allow non-integers for timestamps
	// Dinotrace doesn't mind, but Cadence Vision seems to choke
	if (VL_UNLIKELY(timeui < m_timeLastDump)) {
		timeui = m_timeLastDump;
		static VL_THREAD_LOCAL bool backTime = false;
		if (!backTime) {
			backTime = true;
			VL_PRINTF_MT("%%Warning: VCD time is moving backwards, wave file may be incorrect.\n");
		}
	}

	uint64_t timeDelta = timeui - m_timeLastDump;
	m_filep->writeVarLenCmd(SigCmd_TimeDelta8, timeDelta);
	bufferCheck();

	m_timeLastDump = timeui;
	//printQuad(timeui);
}

//======================================================================
// Static members

void VerilatedVcd::flush_all() VL_MT_UNSAFE_ONE {
	VerilatedVcdSingleton::flush_all();
}
