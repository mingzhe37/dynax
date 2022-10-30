import jax
import jax.numpy as jnp
import pandas as pd 
import numpy as np
from jax import jit
from jax import grad
from diffrax import diffeqsolve, ODETerm, Euler, Dopri5, SaveAt, PIDController
import matplotlib.pyplot as plt
import time 


n_devices = jax.local_device_count()
print(n_devices)
# a simple RC zone model -> ODE system
"""
This is a 4r3c model for zone temperature prediction
ODE::   xdot = Ax + Bd
        y = Cx
States:
        x = [Tai, Twe, Twi]'
Disturbances:
        u = [Tao, qCon_i, qHVAC, qRad_e, qRad_i]'
Output:
        y = [Tai]
===================================================
"""

@jit
def get_ABCD(Cai, Cwe, Cwi, Re, Ri, Rw, Rg):
    A = jnp.zeros((3, 3))
    B = jnp.zeros((3, 5))
    C = jnp.zeros((1, 3))
    A = A.at[0, 0].set(-1/Cai*(1/Rg+1/Ri))
    A = A.at[0, 2].set(1/(Cai*Ri))
    A = A.at[1, 1].set(-1/Cwe*(1/Re+1/Rw))
    A = A.at[1, 2].set(1/(Cwe*Rw))
    A = A.at[2, 0].set(1/(Cwi*Ri))
    A = A.at[2, 1].set(1/(Cwi*Rw))
    A = A.at[2, 2].set(-1/Cwi*(1/Rw+1/Ri))

    B = B.at[0, 0].set(1/(Cai*Rg))
    B = B.at[0, 1].set(1/Cai)
    B = B.at[0, 2].set(1/Cai)
    B = B.at[1, 0].set(1/(Cwe*Re))
    B = B.at[1, 3].set(1/Cwe)
    B = B.at[2, 4].set(1/Cwi)

    C = C.at[0, 0].set(1)

    D = 0

    return A, B, C, D

@jit
def zone_state_space(t, x, A, B, d):
    x = x.reshape(-1, 1)
    d = d.reshape(-1, 1)
    dx = jnp.matmul(A, x) + jnp.matmul(B, d)
    dx = dx.reshape(-1)

    return dx

## Using for loop to update the disturbance every time step
def forward(func, ts, te, dt, x0, solver, args):
    # unpack args
    A, B, d = args

    # ode formulation
    term = ODETerm(func)

    # initial step
    tprev = ts
    tnext = ts + dt 
    dprev = d[0,:]
    args = (A, B, dprev)
    state = solver.init(term, tprev, tnext, x0, args)

    # initialize output
    t_all = [tprev]
    x_all = jnp.array([x0])

    # main loop
    i = 0
    x = x0

    while tprev < te - dt:
        x, _, _, state, _ = solver.step(term, tprev, tnext, x, args, state, made_jump=False)
        tprev = tnext 
        tnext = min(tprev + dt, te)

        # update disturbance for next step
        i += 1
        dnext = d[i,:]
        args = (A,B,dnext)

        # append results
        t_all.append(tnext)
        x_att = x.reshape(1,-1)
        x_all = jnp.concatenate([x_all, x_att], axis=0)
    
    return t_all, x_all 


### Parameter Inference
dt = 3600
# load training data
data = pd.read_csv('./data/disturbance_1min.csv', index_col=[0])
n = len(data)
index = range(0, n*60, 60)
data.index = index
data = data.groupby([data.index // dt]).mean()

# split training and testing
ratio = 0.1
n_train = int(len(data)*ratio)
print(n_train)
data_train = data.iloc[:n_train, :]
data_test = data.iloc[n_train:, :]

# define training parameters 
ts = 0
te = ts + n_train*dt
solver = Euler()

# forward steps
f = lambda t, x, args: zone_state_space(t, x, *args)#args[0], args[1], args[2]) 
def forward_parameters(p,x, ts, te, dt, solver, d):
    """
    p is [Cai, Cwe, Cwi, Re, Ri, Rw, Rg, Twe0, Twi0]
    x is Tz0
    """
    Cai, Cwe, Cwi, Re, Ri, Rw, Rg, Twe0, Twi0 = p
    A, B, C, D = get_ABCD(Cai, Cwe, Cwi, Re, Ri, Rw, Rg)
    args = (A, B, d)

    # intial point
    x0 = jnp.array([x, Twe0, Twi0])

    # forward calculation
    t, x = forward(f, ts, te, dt, x0, solver, args)

    return t, x 

model = lambda p,x: forward_parameters(p, x, ts, te, dt, solver, d)

# loss function
def loss_fcn(p, x, y_true):
    _, y_pred = model(p, x)
    return jnp.mean((y_pred[:,0] - y_true)**2)

# update 
@jit 
def update(p, x, y_true, lr = 0.1):
    return p - lr*jax.numpy.clip(jax.grad(loss_fcn)(p, x, y_true), -10, 10)

# data preparation
d = data_train.values[:,:5]
y_train = data_train.values[:,5]

p = jnp.array([1., 1., 1., 1., 1., 1., 1., 32., 26.])
x0 = y_train[0]

nepochs = 1000
lr = 0.00001
for i in range(nepochs):
    p = update(p, x0, y_train, lr)

    if i % 100 == 0:
        print(f"======= epoch: {i}")

print(p)
print(loss_fcn(p, x0, y_train))