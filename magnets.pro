// include parameters common to geometry and solver
Include "magnets_data.pro"

DefineConstant[
  Flag_Analysis = {0,
    Choices { 0 = "H-formulation", 1 = "A-formulation"},
    Name "Parameters/0Formulation" }
];

Group{
  Vol_Magnets_Mag = Region[{}];
  For i In {1:NumMagnets}
    Magnet~{i} = Region[i]; // volume of magnet i
    SkinMagnet~{i} = Region[(100+i)]; // boundary of magnet i
    Vol_Magnets_Mag += Region[Magnet~{i}]; // all the magnet volumes
  EndFor
  Air = Region[(NumMagnets + 1)];
  Vol_Mag = Region[{Air, Vol_Magnets_Mag}];
  Dirichlet_phi_0 = Region[(NumMagnets + 2)]; // boundary of air box
  Dirichlet_a_0 = Region[(NumMagnets + 2)]; // boundary of air box
}

Function{
  mu0 = 4*Pi*1e-7;
  mu[Air] = mu0;
  nu[Air] = 1.0/mu0;

  For i In {1:NumMagnets}
    // coercive field of magnets
    DefineConstant[
      HC~{i} = {800e3, Min 0, Max 1e5, Step 1e3,
        Name Sprintf("Parameters/Magnet %g/0Coercive magnetic field [Am^-1]", i)},
      BR~{i} = {mu0 * HC~{i},
        Name Sprintf("Parameters/Magnet %g/0Remnant magnetic flux density [T]", i),
        ReadOnly 1},
      MUR~{i} = {1, Min 1, Max 1000, Step 10,
        Name Sprintf("Parameters/Magnet %g/01Relative permeability", i)}
    ];
    hc[Magnet~{i}] = Rotate[Vector[0, HC~{i}, 0], Rx~{i}, Ry~{i}, Rz~{i}];
    br[Magnet~{i}] = Rotate[Vector[0, BR~{i}, 0], Rx~{i}, Ry~{i}, Rz~{i}];
    mu[Magnet~{i}] = MUR~{i} * mu0;
    nu[Magnet~{i}] = 1.0/(MUR~{i} * mu0);
  EndFor
}

Jacobian {
  { Name JVol ;
    Case {
      { Region All ; Jacobian Vol ; }
    }
  }
}

Integration {
  { Name I1 ;
    Case {
      { Type Gauss ;
        Case {
	  { GeoElement Triangle ; NumberOfPoints 4 ; }
	  { GeoElement Quadrangle  ; NumberOfPoints 4 ; }
          { GeoElement Tetrahedron  ; NumberOfPoints 4 ; }
	}
      }
    }
  }
}

Constraint {
  { Name phi ;
    Case {
      { Region Dirichlet_phi_0 ; Value 0. ; }
    }
  }
  { Name a ;
    Case {
      { Region Dirichlet_a_0 ; Value 0. ; }
    }
  }
  { Name GaugeCondition_a ; Type Assign ;
    Case {
      { Region Vol_Mag ; SubRegion Dirichlet_a_0 ; Value 0. ; }
    }
  }
}

FunctionSpace {
  // scalar magnetic potential
  { Name Hgrad_phi ; Type Form0 ;
    BasisFunction {
      { Name sn ; NameOfCoef phin ; Function BF_Node ;
        Support Vol_Mag ; Entity NodesOf[ All ] ; }
    }
    Constraint {
      { NameOfCoef phin ; EntityType NodesOf ; NameOfConstraint phi ; }
    }
  }
  // vector magnetic potential
  { Name Hcurl_a; Type Form1;
    BasisFunction {
      { Name se;  NameOfCoef ae;  Function BF_Edge; Support Vol_Mag ;
        Entity EdgesOf[ All ]; }
    }
    Constraint {
      { NameOfCoef ae;  EntityType EdgesOf ; NameOfConstraint a; }
      { NameOfCoef ae;  EntityType EdgesOfTreeIn ; EntitySubType StartingOn ;
        NameOfConstraint GaugeCondition_a ; }
    }
  }
}

Formulation {
  { Name MagSta_phi ; Type FemEquation ;
    Quantity {
      { Name phi ; Type Local ; NameOfSpace Hgrad_phi ; }
    }
    Equation {
      Integral { [ - mu[] * Dof{d phi} , {d phi} ] ;
        In Vol_Mag ; Jacobian JVol ; Integration I1 ; }
      Integral { [ - mu[] * hc[] , {d phi} ] ;
        In Vol_Magnets_Mag ; Jacobian JVol ; Integration I1 ; }
    }
  }
  { Name MagSta_a; Type FemEquation ;
    Quantity {
      { Name a  ; Type Local  ; NameOfSpace Hcurl_a ; }
    }
    Equation {
      Integral { [ nu[] * Dof{d a} , {d a} ] ;
        In Vol_Mag ; Jacobian JVol ; Integration I1 ; }
      Integral { [ nu[] * br[] , {d a} ] ;
        In Vol_Magnets_Mag ; Jacobian JVol ; Integration I1 ; }
    }
  }
}

Resolution {
  { Name MagSta_phi ;
    System {
      { Name A ; NameOfFormulation MagSta_phi ; }
    }
    Operation {
      Generate[A] ; Solve[A] ; SaveSolution[A] ;
      PostOperation[MagSta_phi] ;
    }
  }
  { Name MagSta_a ;
    System {
      { Name A ; NameOfFormulation MagSta_a ; }
    }
    Operation {
      Generate[A] ; Solve[A] ; SaveSolution[A] ;
      PostOperation[MagSta_a] ;
    }
  }
  { Name Analysis ;
    System {
      If(Flag_Analysis == 0)
        { Name A ; NameOfFormulation MagSta_phi ; }
      EndIf
      If(Flag_Analysis == 1)
        { Name A ; NameOfFormulation MagSta_a ; }
      EndIf
    }
    Operation {
      Generate[A] ; Solve[A] ; SaveSolution[A] ;
      If(Flag_Analysis == 0)
        PostOperation[MagSta_phi] ;
      EndIf
      If(Flag_Analysis == 1)
        PostOperation[MagSta_a] ;
      EndIf
    }
  }
}

PostProcessing {
  { Name MagSta_phi ; NameOfFormulation MagSta_phi ;
    Quantity {
      { Name b ; Value {
          Term { [ - mu[] * {d phi} ] ; In Vol_Mag ; Jacobian JVol ; }
          Term { [ - mu[] * hc[] ]    ; In Vol_Magnets_Mag ; Jacobian JVol ; }
        }
      }
      { Name h ; Value {
          Term { [ - {d phi} ] ; In Vol_Mag ; Jacobian JVol ; }
        }
      }
      { Name hc ; Value {
          Term { [ hc[] ] ; In Vol_Magnets_Mag ; Jacobian JVol ; }
        }
      }
      { Name phi ; Value {
          Term { [ {phi} ] ; In Vol_Mag ; Jacobian JVol ; }
        }
      }
    }
  }
  { Name MagSta_a ; NameOfFormulation MagSta_a ;
    PostQuantity {
      { Name b ; Value {
          Term { [ {d a} ]; In Vol_Mag ; Jacobian JVol; }
        }
      }
      { Name a ; Value {
          Term { [ {a} ]; In Vol_Mag ; Jacobian JVol; }
        }
      }
      { Name br ; Value {
          Term { [ br[] ]; In Vol_Magnets_Mag ; Jacobian JVol; }
        }
      }
    }
  }
}

PostOperation {
  { Name MagSta_phi ; NameOfPostProcessing MagSta_phi;
    Operation {
      Print[ b, OnElementsOf Vol_Mag, File "b.pos" ] ;
      Print[ b, OnPlane{ {-0.1,-0.1,0} {0.1,-0.1,0} {-0.1,0.1,0} } {50, 50},
        File "b_cut1.pos" ];
      //Print[ h, OnElementsOf Vol_Mag, File "h.pos" ] ;
      //Print[ hc, OnElementsOf Vol_Mag, File "hc.pos" ] ;
    }
  }
  { Name MagSta_a ; NameOfPostProcessing MagSta_a ;
    Operation {
      Print[ b,  OnElementsOf Vol_Mag,  File "b.pos" ];
      Print[ b, OnPlane{ {-0.1,-0.1,0} {0.1,-0.1,0} {-0.1,0.1,0} } {50, 50},
        File "b_cut1.pos" ];
      //Print[ br,  OnElementsOf Vol_Magnets_Mag,  File "br.pos" ];
      //Print[ a,  OnElementsOf Vol_Mag,  File "a.pos" ];
    }
  }
}

DefineConstant[
  // preset all getdp options and make them invisible
  R_ = {"Analysis", Name "GetDP/1ResolutionChoices", Visible 0},
  C_ = {"-solve -v 5 -v2 -bin", Name "GetDP/9ComputeCommand", Visible 0}
  P_ = {"", Name "GetDP/2PostOperationChoices", Visible 0}
];
