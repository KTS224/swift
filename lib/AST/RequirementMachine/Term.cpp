//===--- Term.cpp - A term in the generics rewrite system -----------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/AST/Decl.h"
#include "swift/AST/Types.h"
#include "llvm/ADT/FoldingSet.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <vector>
#include "ProtocolGraph.h"
#include "RewriteContext.h"
#include "Symbol.h"
#include "Term.h"

using namespace swift;
using namespace rewriting;

/// Terms are uniqued and immutable, stored as a single pointer;
/// the Storage type is the allocated backing storage.
struct Term::Storage final
  : public llvm::FoldingSetNode,
    public llvm::TrailingObjects<Storage, Symbol> {
  friend class Symbol;

  unsigned Size;

  explicit Storage(unsigned size) : Size(size) {}

  size_t numTrailingObjects(OverloadToken<Symbol>) const {
    return Size;
  }

  MutableArrayRef<Symbol> getElements() {
    return {getTrailingObjects<Symbol>(), Size};
  }

  ArrayRef<Symbol> getElements() const {
    return {getTrailingObjects<Symbol>(), Size};
  }

  void Profile(llvm::FoldingSetNodeID &id) const;
};

size_t Term::size() const { return Ptr->Size; }

ArrayRef<Symbol>::iterator Term::begin() const {
  return Ptr->getElements().begin();
}

ArrayRef<Symbol>::iterator Term::end() const {
  return Ptr->getElements().end();
}

ArrayRef<Symbol>::reverse_iterator Term::rbegin() const {
  return Ptr->getElements().rbegin();
}

ArrayRef<Symbol>::reverse_iterator Term::rend() const {
  return Ptr->getElements().rend();
}

Symbol Term::back() const {
  return Ptr->getElements().back();
}

Symbol Term::operator[](size_t index) const {
  return Ptr->getElements()[index];
}

void Term::dump(llvm::raw_ostream &out) const {
  MutableTerm(*this).dump(out);
}

Term Term::get(const MutableTerm &mutableTerm, RewriteContext &ctx) {
  unsigned size = mutableTerm.size();
  assert(size > 0 && "Term must have at least one symbol");

  llvm::FoldingSetNodeID id;
  id.AddInteger(size);
  for (auto symbol : mutableTerm)
    id.AddPointer(symbol.getOpaquePointer());

  void *insertPos = nullptr;
  if (auto *term = ctx.Terms.FindNodeOrInsertPos(id, insertPos))
    return term;

  void *mem = ctx.Allocator.Allocate(
      Storage::totalSizeToAlloc<Symbol>(size),
      alignof(Storage));
  auto *term = new (mem) Storage(size);
  for (unsigned i = 0; i < size; ++i)
    term->getElements()[i] = mutableTerm[i];

  ctx.Terms.InsertNode(term, insertPos);

  return term;
}

void Term::Storage::Profile(llvm::FoldingSetNodeID &id) const {
  id.AddInteger(Size);

  for (auto symbol : getElements())
    id.AddPointer(symbol.getOpaquePointer());
}

/// Returns the "domain" of this term by looking at the first symbol.
///
/// - If the first symbol is a protocol symbol [P], the domain is P.
/// - If the first symbol is an associated type symbol [P1&...&Pn],
///   the domain is {P1, ..., Pn}.
/// - If the first symbol is a generic parameter symbol, the domain is
///   the empty set {}.
/// - Anything else will assert.
ArrayRef<const ProtocolDecl *> MutableTerm::getRootProtocols() const {
  auto symbol = *begin();

  switch (symbol.getKind()) {
  case Symbol::Kind::Protocol:
  case Symbol::Kind::AssociatedType:
    return symbol.getProtocols();

  case Symbol::Kind::GenericParam:
    return ArrayRef<const ProtocolDecl *>();

  case Symbol::Kind::Name:
  case Symbol::Kind::Layout:
  case Symbol::Kind::Superclass:
  case Symbol::Kind::ConcreteType:
    break;
  }

  llvm_unreachable("Bad root symbol");
}

/// Shortlex order on terms.
///
/// First we compare length, then perform a lexicographic comparison
/// on symbols if the two terms have the same length.
int MutableTerm::compare(const MutableTerm &other,
                         const ProtocolGraph &graph) const {
  if (size() != other.size())
    return size() < other.size() ? -1 : 1;

  for (unsigned i = 0, e = size(); i < e; ++i) {
    auto lhs = (*this)[i];
    auto rhs = other[i];

    int result = lhs.compare(rhs, graph);
    if (result != 0) {
      assert(lhs != rhs);
      return result;
    }

    assert(lhs == rhs);
  }

  return 0;
}

/// Find the start of \p other in this term, returning end() if
/// \p other does not occur as a subterm of this term.
decltype(MutableTerm::Symbols)::const_iterator
MutableTerm::findSubTerm(const MutableTerm &other) const {
  if (other.size() > size())
    return end();

  return std::search(begin(), end(), other.begin(), other.end());
}

/// Non-const variant of the above.
decltype(MutableTerm::Symbols)::iterator
MutableTerm::findSubTerm(const MutableTerm &other) {
  if (other.size() > size())
    return end();

  return std::search(begin(), end(), other.begin(), other.end());
}

/// Replace the first occurrence of \p lhs in this term with
/// \p rhs. Note that \p rhs must precede \p lhs in the linear
/// order on terms. Returns true if the term contained \p lhs;
/// otherwise returns false, in which case the term remains
/// unchanged.
bool MutableTerm::rewriteSubTerm(const MutableTerm &lhs,
                                 const MutableTerm &rhs) {
  // Find the start of lhs in this term.
  auto found = findSubTerm(lhs);

  // This term cannot be reduced using this rule.
  if (found == end())
    return false;

  auto oldSize = size();

  assert(rhs.size() <= lhs.size());

  // Overwrite the occurrence of the left hand side with the
  // right hand side.
  auto newIter = std::copy(rhs.begin(), rhs.end(), found);
  auto oldIter = found + lhs.size();

  // If the right hand side is shorter than the left hand side,
  // then newIter will point to a location before oldIter, eg
  // if this term is 'T.A.B.C', lhs is 'A.B' and rhs is 'X',
  // then we now have:
  //
  // T.X  .C
  //       ^--- oldIter
  //     ^--- newIter
  //
  // Shift everything over to close the gap (by one location,
  // in this case).
  if (newIter != oldIter) {
    auto newEnd = std::copy(oldIter, end(), newIter);

    // Now, we've moved the gap to the end of the term; close
    // it by shortening the term.
    Symbols.erase(newEnd, end());
  }

  assert(size() == oldSize - lhs.size() + rhs.size());
  return true;
}

void MutableTerm::dump(llvm::raw_ostream &out) const {
  bool first = true;

  for (auto symbol : Symbols) {
    if (!first)
      out << ".";
    else
      first = false;

    symbol.dump(out);
  }
}