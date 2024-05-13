using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

public class BillboardGrass : MonoBehaviour {
    public int width = 10;
    public int length = 10;
    public int density = 1;
    public Material grassMaterial;
    public Mesh grassMesh;
    public bool updateGrass;

    private ComputeShader initializeGrassShader;
    private ComputeBuffer grassDataBuffer, argsBuffer;
    private Material grassMaterial2, grassMaterial3;
    
    private struct GrassData {
        public Vector4 position;
        public Vector2 uv;
    }

    void Start() {
        initializeGrassShader = Resources.Load<ComputeShader>("GrassPoint");
        grassDataBuffer = new ComputeBuffer(width * length * density * density, 4 *6);
        argsBuffer = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);

        updateGrassBuffer();
    }
    
    void updateGrassBuffer() {
        initializeGrassShader.SetInt("_Width", width * density);
        initializeGrassShader.SetInt("_Length", length * density);
        initializeGrassShader.SetInt("_Density", density);
        initializeGrassShader.SetBuffer(0, "_GrassDataBuffer", grassDataBuffer);
        initializeGrassShader.Dispatch(0, Mathf.CeilToInt(width * density / 8.0f), Mathf.CeilToInt(length * density / 8.0f), 1);
        grassMaterial.SetBuffer("positionBuffer", grassDataBuffer);
        
        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        // Arguments for drawing mesh.
        // 0 == number of triangle indices, 1 == population, others are only relevant if drawing submeshes.
        args[0] = (uint)grassMesh.GetIndexCount(0);
        args[1] = (uint)grassDataBuffer.count;
        args[2] = (uint)grassMesh.GetIndexStart(0);
        args[3] = (uint)grassMesh.GetBaseVertex(0);
        argsBuffer.SetData(args);
        
        grassMaterial.SetBuffer("positionBuffer", grassDataBuffer);
        grassMaterial.SetFloat("_Rotation", 0.0f);
        grassMaterial2 = new Material(grassMaterial);
        grassMaterial2.SetBuffer("positionBuffer", grassDataBuffer);
        grassMaterial2.SetFloat("_Rotation", 50.0f);
        grassMaterial3 = new Material(grassMaterial);
        grassMaterial3.SetBuffer("positionBuffer", grassDataBuffer);
        grassMaterial3.SetFloat("_Rotation", -50.0f);
    }

    void Update() {
        Graphics.DrawMeshInstancedIndirect(grassMesh, 0, grassMaterial, new Bounds(Vector3.zero, new Vector3(-500.0f, 200.0f, 500.0f)), argsBuffer);
        Graphics.DrawMeshInstancedIndirect(grassMesh, 0, grassMaterial2, new Bounds(Vector3.zero, new Vector3(-500.0f, 200.0f, 500.0f)), argsBuffer);
        Graphics.DrawMeshInstancedIndirect(grassMesh, 0, grassMaterial3, new Bounds(Vector3.zero, new Vector3(-500.0f, 200.0f, 500.0f)), argsBuffer);

        if (updateGrass) {
            updateGrassBuffer();
            updateGrass = false;
        }

    }
    
    void OnDisable() {
        grassDataBuffer.Release();
        argsBuffer.Release();
        grassDataBuffer = null;
        argsBuffer = null;
    }
}
