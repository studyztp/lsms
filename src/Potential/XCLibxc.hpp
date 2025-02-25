//
// Created by F.Moitzi on 24.04.2022.
//

#ifndef LSMS_XCLIBXC_HPP
#define LSMS_XCLIBXC_HPP

#include "XCBase.hpp"

#ifdef USE_LIBXC

#include <xc.h>

namespace lsms {

class XCFuncType {
 private:
  bool initialized{false};
  xc_func_type _func_type;
  int _nspin;

 public:

  XCFuncType() = delete;

  XCFuncType(int nspin, int type);

  XCFuncType(const XCFuncType & other);

  ~XCFuncType() noexcept;

  [[nodiscard]] auto xc_info() const {
    return _func_type.info;
  }


  [[nodiscard]] const xc_func_type & get_functional() const;
};

class XCLibxc : public XCBase {
 private:
  std::vector<XCFuncType> functionals;  // functionals
  std::size_t numFunctionals;
  bool needGradients;  // functional needs gradients of the density (GGA)
  bool needLaplacian;  // need laplacians of the density (MetaGGA)
  bool needKineticEnergyDensity;  // for MetaGGAs
  bool needExactExchange;         // for Hybrid Functionals

 public:
  XCLibxc(int nSpin, std::vector<int> xcFunctional);

  XCLibxc(int nSpin, int xcFunctional[3]);

  void evaluate(const std::vector<Real> &rMesh, double h, const Matrix<Real> &rhoIn,
                int jmt, Matrix<Real> &xcEnergyOut,
                Matrix<Real> &xcPotOut) override;

  void evaluate(const Real rhoIn[2], Real &xcEnergyOut,
                Real xcPotOut[2]) override;

  [[nodiscard]] const std::vector<XCFuncType> &get_functionals() const;

  std::string get_name() override;

 private:
  template<typename II>
  void setup(int nSpin, II first, II last) {
    needGradients = false;
    needLaplacian = false;
    needGradients = false;
    needKineticEnergyDensity = false;
    needExactExchange = false;
    numFunctionals = 0;

    if (*first != 1) {
      throw std::runtime_error("Not a `libxc` functional");
    }

    for (II xcFunctional = first + 1; xcFunctional != last; ++xcFunctional) {
      int xc_id = *xcFunctional;

      int nspin = XC_UNPOLARIZED;
      if (nSpin > 1) nspin = XC_POLARIZED;

      if (xc_id > 0) {
        functionals.emplace_back(nspin, xc_id);

        switch (functionals[numFunctionals].get_functional().info->family) {
          case XC_FAMILY_LDA:break;
          case XC_FAMILY_GGA:needGradients = true;
            break;
          case XC_FAMILY_HYB_GGA:needGradients = true;
            needExactExchange = true;
            break;
          case XC_FAMILY_MGGA:needGradients = true;
            needLaplacian = true;
            needKineticEnergyDensity = true;
            break;
          default:
            throw std::runtime_error(
                "Unknown Functional family in `libxc` for functional!");
        }

        numFunctionals++;
      }
    }
  }
};

}  // namespace lsms

#endif

#endif  // LSMS_XCLIBXC_HPP
