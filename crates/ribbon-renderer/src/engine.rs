use ribbon_core::{Result, RibbonError};
use winit::window::Window;

pub struct RenderEngine<'window> {
    /// the drawing surface that connects wgpu to the os window.
    pub surface: wgpu::Surface<'window>,

    /// the logical connection to the physical gpu.
    pub device: wgpu::Device,

    /// the command queue where we submit our async rendering instructions.
    pub queue: wgpu::Queue,

    /// the configuration of the swapchain (resolution, vsync, color format)
    pub config: wgpu::SurfaceConfiguration,

    /// the current physical size of the window.
    pub size: winit::dpi::PhysicalSize<u32>,
}

impl<'window> RenderEngine<'window> {
    /// asynchronously initializes the wgpu backend, selects the best physical gpu,
    /// and establishes the logical device and command queue.
    pub async fn new(window: &'window Window) -> Result<Self> {
        let size = window.inner_size();

        let instance = wgpu::Instance::default();

        let surface = instance
            .create_surface(window)
            .map_err(|e| RibbonError::Render(format!("failed to create wgpu surface: {}", e)))?;

        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: Some(&surface),
                force_fallback_adapter: false,
            })
            .await
            .map_err(|e| {
                RibbonError::Render(format!("no compatible high-performance gpu found: {}", e))
            })?;

        let (device, queue) = adapter
            .request_device(&wgpu::DeviceDescriptor {
                label: Some("ribbon_device"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::default(),
                memory_hints: wgpu::MemoryHints::Performance,
                experimental_features: wgpu::ExperimentalFeatures::disabled(),
                trace: wgpu::Trace::Off,
            })
            .await
            .map_err(|e| RibbonError::Render(format!("failed to acquire logical device: {}", e)))?;

        let surface_caps = surface.get_capabilities(&adapter);
        let surface_format = surface_caps
            .formats
            .iter()
            .copied()
            .find(|f| f.is_srgb())
            .unwrap_or(surface_caps.formats[0]);

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface_format,
            width: size.width.max(1),
            height: size.height.max(1),
            present_mode: wgpu::PresentMode::Fifo,
            alpha_mode: surface_caps.alpha_modes[0],
            view_formats: vec![],
            desired_maximum_frame_latency: 2,
        };

        surface.configure(&device, &config);

        Ok(Self {
            surface,
            device,
            queue,
            config,
            size,
        })
    }

    /// updates the surface configuration. this must be called every time the window is
    /// resized to prevent swapchain panics.
    pub fn resize(&mut self, new_size: winit::dpi::PhysicalSize<u32>) {
        if new_size.width > 0 && new_size.height > 0 {
            self.size = new_size;
            self.config.width = new_size.width;
            self.config.height = new_size.height;
            self.surface.configure(&self.device, &self.config);
        }
    }

    /// allows changing the presentation mode on the fly
    pub fn set_present_mode(&mut self, mode: wgpu::PresentMode) {
        self.config.present_mode = mode;
        self.surface.configure(&self.device, &self.config);
    }

    /// begins a new frame. it acquires the next available texture from the swapchain
    /// and prepares a command decoder.
    pub fn begin_frame(
        &self,
    ) -> Result<(
        wgpu::SurfaceTexture,
        wgpu::TextureView,
        wgpu::CommandEncoder,
    )> {
        let surface_texture = match self.surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(texture) => texture,
            wgpu::CurrentSurfaceTexture::Suboptimal(texture) => texture,
            wgpu::CurrentSurfaceTexture::Timeout => {
                return Err(RibbonError::Render("swapchain timeout".to_string()));
            }
            wgpu::CurrentSurfaceTexture::Occluded => {
                return Err(RibbonError::Render("swapchain occluded".to_string()));
            }
            wgpu::CurrentSurfaceTexture::Outdated => {
                return Err(RibbonError::Render("swapchain outdated".to_string()));
            }
            wgpu::CurrentSurfaceTexture::Lost => {
                return Err(RibbonError::Render("swapchain lost".to_string()));
            }
            wgpu::CurrentSurfaceTexture::Validation => {
                return Err(RibbonError::Render(
                    "swapchain validation error".to_string(),
                ));
            }
        };

        let texture_view = surface_texture
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("ribbon_frame_encoder"),
            });

        Ok((surface_texture, texture_view, encoder))
    }

    /// submits the recorded commands to the gpu and presents the frame to the screen.
    pub fn submit_frame(
        &self,
        surface_texture: wgpu::SurfaceTexture,
        encoder: wgpu::CommandEncoder,
    ) {
        self.queue.submit(std::iter::once(encoder.finish()));

        surface_texture.present();
    }
}
