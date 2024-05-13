using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ModelGrass : MonoBehaviour {
    public int width = 10;
    public int length = 10;
    public int density = 1;
    public Material grassMaterial;
    public Mesh grassMesh;
    public bool isInstanced = true;

    public bool updateGrass;

    [Header("Wind")]
    public float windSpeed = 1.0f;
    public float frequency = 1.0f;
    public float windStrength = 1.0f;

    private ComputeShader initializeGrassShader, generateWindShader;
    private ComputeBuffer grassDataBuffer;
    private ComputeBuffer argsBuffer;

    private RenderTexture wind;

    private Material matInstance;

    private struct GrassData {
        public Vector4 position;
        public Vector2 uv;
    }

    void OnEnable() {

        initializeGrassShader = Resources.Load<ComputeShader>("GrassPoint");
        generateWindShader = Resources.Load<ComputeShader>("WindNoise");
        grassDataBuffer = new ComputeBuffer(width * length * density * density, 4 * 6);
        argsBuffer = new ComputeBuffer(1, 5 * sizeof(uint), ComputeBufferType.IndirectArguments);

        if (isInstanced)
        {
            matInstance = new Material(grassMaterial);
        }
        else
        {
            matInstance = grassMaterial;
        }
        
        wind = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        wind.enableRandomWrite = true;
        wind.Create();

        updateGrassBuffer();
    }

    void updateGrassBuffer() {
        initializeGrassShader.SetInt("_Width", width * density);
        initializeGrassShader.SetInt("_Length", length * density);
        initializeGrassShader.SetInt("_Density", density);
        initializeGrassShader.SetFloat("_XCenter", transform.position.x);
        initializeGrassShader.SetFloat("_YCenter", transform.position.y);
        initializeGrassShader.SetFloat("_ZCenter", transform.position.z);
        initializeGrassShader.SetBuffer(0, "_GrassDataBuffer", grassDataBuffer);
        initializeGrassShader.Dispatch(0, Mathf.CeilToInt(width * density / 8.0f), Mathf.CeilToInt(length * density / 8.0f), 1);

        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        // Arguments for drawing mesh.
        // 0 == number of triangle indices, 1 == population, others are only relevant if drawing submeshes.
        args[0] = (uint)grassMesh.GetIndexCount(0);
        args[1] = (uint)grassDataBuffer.count;
        args[2] = (uint)grassMesh.GetIndexStart(0);
        args[3] = (uint)grassMesh.GetBaseVertex(0);
        argsBuffer.SetData(args);
        
        GenerateWind();

        matInstance.SetBuffer("positionBuffer", grassDataBuffer);
        matInstance.SetTexture("_WindTex", wind);
    }

    void GenerateWind() {
        generateWindShader.SetTexture(0, "_WindMap", wind);
        generateWindShader.SetFloat("_Time", Time.time * windSpeed);
        generateWindShader.SetFloat("_Frequency", frequency);
        generateWindShader.SetFloat("_Amplitude", windStrength);
        generateWindShader.Dispatch(0, Mathf.CeilToInt(wind.width / 8.0f), Mathf.CeilToInt(wind.height / 8.0f), 1);
    }

    void Update() {      
        GenerateWind();

        matInstance.SetBuffer("positionBuffer", grassDataBuffer);
        matInstance.SetTexture("_WindTex", wind);

        Graphics.DrawMeshInstancedIndirect(grassMesh, 0, matInstance, new Bounds(Vector3.zero, new Vector3(-500.0f, 200.0f, 500.0f)), argsBuffer);

        if (updateGrass) {
            updateGrassBuffer();
            updateGrass = false;
        }
    }
    
    void OnDisable() {
        grassDataBuffer.Release();
        argsBuffer.Release();
        wind.Release();
        grassDataBuffer = null;
        argsBuffer = null;
        wind = null;
    }
    
    private void OnDrawGizmos()
    {
        Gizmos.color = Color.yellow;

        // Calculate half of width and length
        float halfWidth = width * 0.5f;
        float halfLength = length * 0.5f;

        // Get the center position of the square
        Vector3 center = transform.position;

        // Define the four corner points of the square
        Vector3 topLeft = center + new Vector3(-halfWidth, 0f, halfLength);
        Vector3 topRight = center + new Vector3(halfWidth, 0f, halfLength);
        Vector3 bottomLeft = center + new Vector3(-halfWidth, 0f, -halfLength);
        Vector3 bottomRight = center + new Vector3(halfWidth, 0f, -halfLength);

        // Draw the square using Gizmos.DrawLine
        Gizmos.DrawLine(topLeft, topRight);
        Gizmos.DrawLine(topRight, bottomRight);
        Gizmos.DrawLine(bottomRight, bottomLeft);
        Gizmos.DrawLine(bottomLeft, topLeft);
    }
}
