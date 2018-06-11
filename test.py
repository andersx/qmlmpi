#!/usr/bin/env python
from __future__ import print_function, absolute_import

import os
import numpy as np

import scipy
from scipy.linalg import lstsq

import qml
from qml.kernels import laplacian_kernel
from qml.math import cho_solve

from qml_mpi import get_alphas, write_input

def get_energies(filename):
    """ Returns a dictionary with heats of formation for each xyz-file.
    """

    f = open(filename, "r")
    lines = f.readlines()
    f.close()

    energies = dict()

    for line in lines:
        tokens = line.split()

        xyz_name = tokens[0]
        hof = float(tokens[1])

        energies[xyz_name] = hof

    return energies

def get_data():
    """" Generate coulomb matrices and heat of formation for QM7.
    """
    
    test_dir = os.path.dirname(os.path.realpath(__file__))

    # Parse file containing PBE0/def2-TZVP heats of formation and xyz filenames
    data = get_energies(test_dir + "/data/hof_qm7.txt")

    # Generate a list of qml.Compound() objects
    mols = []

    for xyz_file in sorted(data.keys())[:1000]:

        # Initialize the qml.Compound() objects
        mol = qml.Compound(xyz=test_dir + "/qm7/" + xyz_file)

        # Associate a property (heat of formation) with the object
        mol.properties = data[xyz_file]

        # This is a Molecular Coulomb matrix sorted by row norm
        mol.generate_coulomb_matrix(size=23, sorting="row-norm")

        mols.append(mol)

    X  = np.array([mol.representation for mol in mols])
    Y = np.array([mol.properties for mol in mols])

    sigma = 10**(4.2)

    return X, Y, sigma

def get_alphas_python(X, Y, sigma):
    """ Get alpha vectors through python.
    """

    K = laplacian_kernel(X, X, sigma)
    alpha, res, sing, rank = lstsq(K, Y, lapack_driver="gelsd")

    return alpha

def get_alphas_fortran_reference(X, Y, sigma):

    n_alphas = X.shape[0]

    alphas= get_alphas(X, Y, sigma, n_alphas)


    return alphas

if __name__ == "__main__":

    X, Y, sigma = get_data()

    alphas1 = get_alphas_python(X, Y, sigma)
    alphas2 = get_alphas_fortran_reference(X, Y, sigma)
    
    assert np.allclose(alphas1, alphas2)
    np.savetxt("alphas_reference.txt", alphas2, fmt="%21.12f", newline="")

    write_input(X, Y, sigma)
